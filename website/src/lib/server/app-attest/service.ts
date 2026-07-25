import { randomBytes, randomUUID } from 'node:crypto';

import { canonicalRequest } from './canonical';
import { AppAttestError, storeUnavailable } from './errors';
import type {
	AppAttestStore,
	AttestationVerifier,
	ChallengeRecord,
	PublicChallenge,
	RequestBinding
} from './types';

const RECENT_COUNTER_WINDOW = 64;

interface AppAttestAuthServiceOptions {
	store: AppAttestStore;
	verifier: AttestationVerifier;
	challengeTTLMilliseconds?: number;
	now?: () => Date;
}

export class AppAttestAuthService {
	readonly #store: AppAttestStore;
	readonly #verifier: AttestationVerifier;
	readonly #challengeTTLMilliseconds: number;
	readonly #now: () => Date;

	constructor(options: AppAttestAuthServiceOptions) {
		this.#store = options.store;
		this.#verifier = options.verifier;
		this.#challengeTTLMilliseconds = options.challengeTTLMilliseconds ?? 300_000;
		this.#now = options.now ?? (() => new Date());
	}

	async ready(): Promise<void> {
		try {
			await this.#store.ping();
		} catch (error) {
			throw storeUnavailable(error);
		}
	}

	async createRegistrationChallenge(keyId: string): Promise<PublicChallenge> {
		return this.#createChallenge({ purpose: 'registration', keyId });
	}

	async createAssertionChallenge(keyId: string, request: RequestBinding): Promise<PublicChallenge> {
		let key;
		try {
			key = await this.#store.getKey(keyId);
		} catch (error) {
			throw storeUnavailable(error);
		}
		if (!key) {
			throw new AppAttestError('unknown_app_attest_key', 401, 'App Attest key is not registered');
		}
		return this.#createChallenge({ purpose: 'assertion', keyId, request });
	}

	async register(input: {
		challengeId: string;
		keyId: string;
		attestation: Buffer;
	}): Promise<void> {
		const challenge = await this.#requiredChallenge(input.challengeId);
		if (challenge.purpose !== 'registration' || challenge.keyId !== input.keyId) {
			throw new AppAttestError(
				'invalid_app_attest_registration',
				401,
				'Attestation registration does not match its challenge'
			);
		}

		let verified;
		try {
			verified = this.#verifier.verifyAttestation({
				attestation: input.attestation,
				challenge: Buffer.from(challenge.nonce, 'base64url'),
				keyId: input.keyId
			});
		} catch (error) {
			throw new AppAttestError(
				'invalid_app_attest_registration',
				401,
				'Apple App Attest registration is invalid',
				{ cause: error }
			);
		}

		try {
			const result = await this.#store.consumeRegistration(challenge.id, {
				keyId: input.keyId,
				publicKey: verified.publicKey,
				environment: verified.environment,
				highSignCount: 0,
				recentSignCounts: [],
				createdAt: this.#now().toISOString()
			});
			if (result !== 'registered') this.#throwChallengeResult(result);
		} catch (error) {
			if (error instanceof AppAttestError) throw error;
			throw storeUnavailable(error);
		}
	}

	async verifyRequest(input: {
		challengeId: string;
		keyId: string;
		assertion: Buffer;
		request: RequestBinding | (() => Promise<RequestBinding>);
	}): Promise<void> {
		let key;
		try {
			key = await this.#store.getKey(input.keyId);
		} catch (error) {
			throw storeUnavailable(error);
		}
		if (!key) {
			throw new AppAttestError('unknown_app_attest_key', 401, 'App Attest key is not registered');
		}

		const challenge = await this.#requiredChallenge(input.challengeId);
		if (
			challenge.purpose !== 'assertion' ||
			challenge.keyId !== input.keyId ||
			!challenge.request
		) {
			throw new AppAttestError(
				'invalid_app_attest_assertion',
				401,
				'App Attest assertion does not match the HTTP request'
			);
		}
		const request = typeof input.request === 'function' ? await input.request() : input.request;
		if (!sameRequest(challenge.request, request)) {
			throw new AppAttestError(
				'invalid_app_attest_assertion',
				401,
				'App Attest assertion does not match the HTTP request'
			);
		}

		let signCount: number;
		try {
			const payload = Buffer.from(canonicalRequest({ challenge: challenge.nonce, ...request }));
			signCount = this.#verifier.verifyAssertion({
				assertion: input.assertion,
				payload,
				publicKey: key.publicKey,
				minimumSignCount: Math.max(0, key.highSignCount - RECENT_COUNTER_WINDOW)
			}).signCount;
		} catch (error) {
			throw new AppAttestError(
				'invalid_app_attest_assertion',
				401,
				'Apple App Attest assertion is invalid',
				{ cause: error }
			);
		}

		try {
			const result = await this.#store.consumeAssertion({
				challengeId: challenge.id,
				keyId: input.keyId,
				signCount,
				recentCounterWindow: RECENT_COUNTER_WINDOW
			});
			switch (result) {
				case 'accepted': return;
				case 'replayed':
					throw new AppAttestError(
						'replayed_app_attest_assertion',
						409,
						'App Attest assertion has already been used'
					);
				case 'unknown_key':
					throw new AppAttestError('unknown_app_attest_key', 401, 'App Attest key is not registered');
				default: this.#throwChallengeResult(result);
			}
		} catch (error) {
			if (error instanceof AppAttestError) throw error;
			throw storeUnavailable(error);
		}
	}

	async #createChallenge(input: Pick<ChallengeRecord, 'purpose' | 'keyId' | 'request'>): Promise<PublicChallenge> {
		const createdAt = this.#now();
		const challenge: ChallengeRecord = {
			id: randomUUID(),
			nonce: randomBytes(32).toString('base64url'),
			purpose: input.purpose,
			keyId: input.keyId,
			...(input.request ? { request: input.request } : {}),
			createdAt: createdAt.toISOString(),
			expiresAt: new Date(createdAt.getTime() + this.#challengeTTLMilliseconds).toISOString()
		};
		try {
			await this.#store.saveChallenge(challenge);
		} catch (error) {
			throw storeUnavailable(error);
		}
		return { id: challenge.id, challenge: challenge.nonce, expiresAt: challenge.expiresAt };
	}

	async #requiredChallenge(id: string): Promise<ChallengeRecord> {
		let challenge;
		try {
			challenge = await this.#store.getChallenge(id);
		} catch (error) {
			throw storeUnavailable(error);
		}
		if (!challenge || new Date(challenge.expiresAt).getTime() <= this.#now().getTime()) {
			throw new AppAttestError(
				'expired_app_attest_challenge',
				401,
				'App Attest challenge is missing or expired'
			);
		}
		return challenge;
	}

	#throwChallengeResult(result: 'missing_challenge' | 'challenge_mismatch'): never {
		throw new AppAttestError(
			result === 'missing_challenge' ? 'expired_app_attest_challenge' : 'invalid_app_attest_assertion',
			401,
			'App Attest challenge is invalid or expired'
		);
	}
}

function sameRequest(left: RequestBinding, right: RequestBinding): boolean {
	return left.method === right.method &&
		left.pathname === right.pathname &&
		left.query === right.query &&
		left.bodySHA256 === right.bodySHA256;
}
