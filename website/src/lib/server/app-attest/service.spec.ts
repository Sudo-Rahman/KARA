import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';

import type {
	AppAttestStore,
	AttestationVerifier,
	ChallengeRecord,
	RegisteredAppAttestKey,
	RegistrationResult,
	AssertionConsumptionResult
} from './types';
import { AppAttestAuthService } from './service';

class TestStore implements AppAttestStore {
	readonly challenges = new Map<string, ChallengeRecord>();
	readonly keys = new Map<string, RegisteredAppAttestKey>();

	async ping() {}
	async saveChallenge(challenge: ChallengeRecord) { this.challenges.set(challenge.id, challenge); }
	async getChallenge(id: string) { return this.challenges.get(id) ?? null; }
	async getKey(keyId: string) { return this.keys.get(keyId) ?? null; }
	async consumeRegistration(challengeId: string, key: RegisteredAppAttestKey): Promise<RegistrationResult> {
		if (!this.challenges.delete(challengeId)) return 'missing_challenge';
		this.keys.set(key.keyId, key);
		return 'registered';
	}
	async consumeAssertion(input: Parameters<AppAttestStore['consumeAssertion']>[0]): Promise<AssertionConsumptionResult> {
		const challenge = this.challenges.get(input.challengeId);
		if (!challenge) return 'missing_challenge';
		if (challenge.keyId !== input.keyId || challenge.purpose !== 'assertion') return 'challenge_mismatch';
		const key = this.keys.get(input.keyId);
		if (!key) return 'unknown_key';
		if (
			input.signCount <= 0 ||
			input.signCount <= key.highSignCount - input.recentCounterWindow ||
			key.recentSignCounts.includes(input.signCount)
		) return 'replayed';
		key.highSignCount = Math.max(key.highSignCount, input.signCount);
		key.recentSignCounts = [...key.recentSignCounts, input.signCount]
			.filter((value) => value > key.highSignCount - input.recentCounterWindow);
		this.challenges.delete(input.challengeId);
		return 'accepted';
	}
}

class TestVerifier implements AttestationVerifier {
	signCount = 1;
	verifyAttestation() { return { publicKey: 'test-public-key', environment: 'production' as const }; }
	verifyAssertion() { return { signCount: this.signCount }; }
}

describe('AppAttestAuthService', () => {
	it('registers a verified installation from a single-use challenge', async () => {
		const store = new TestStore();
		const verifier = new TestVerifier();
		const service = new AppAttestAuthService({
			store,
			verifier,
			challengeTTLMilliseconds: 300_000,
			now: () => new Date('2026-07-24T10:00:00Z')
		});
		const challenge = await service.createRegistrationChallenge('device-key');

		await service.register({
			challengeId: challenge.id,
			keyId: 'device-key',
			attestation: Buffer.from('attestation')
		});

		expect(await store.getKey('device-key')).toMatchObject({
			keyId: 'device-key',
			publicKey: 'test-public-key',
			environment: 'production',
			highSignCount: 0
		});
		expect(await store.getChallenge(challenge.id)).toBeNull();
	});

	it('accepts unseen concurrent counters out of order and rejects their replay', async () => {
		const store = new TestStore();
		const verifier = new TestVerifier();
		const service = new AppAttestAuthService({ store, verifier });
		store.keys.set('device-key', {
			keyId: 'device-key', publicKey: 'public-key', environment: 'production',
			highSignCount: 0, recentSignCounts: [], createdAt: new Date().toISOString()
		});
		const request = {
			method: 'GET', pathname: '/v1/manifest.json', query: '',
			bodySHA256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
		};

		verifier.signCount = 2;
		const second = await service.createAssertionChallenge('device-key', request);
		await service.verifyRequest({
			challengeId: second.id, keyId: 'device-key', assertion: Buffer.from('two'), request
		});

		verifier.signCount = 1;
		const first = await service.createAssertionChallenge('device-key', request);
		await service.verifyRequest({
			challengeId: first.id, keyId: 'device-key', assertion: Buffer.from('one'), request
		});

		const replay = await service.createAssertionChallenge('device-key', request);
		await expect(service.verifyRequest({
			challengeId: replay.id, keyId: 'device-key', assertion: Buffer.from('one-again'), request
		})).rejects.toMatchObject({ code: 'replayed_app_attest_assertion', status: 409 });
	});

	it('does not consume an assertion challenge for a different request', async () => {
		const store = new TestStore();
		const verifier = new TestVerifier();
		const service = new AppAttestAuthService({ store, verifier });
		store.keys.set('device-key', {
			keyId: 'device-key', publicKey: 'public-key', environment: 'production',
			highSignCount: 0, recentSignCounts: [], createdAt: new Date().toISOString()
		});
		const expected = {
			method: 'GET', pathname: '/v1/manifest.json', query: '',
			bodySHA256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
		};
		const challenge = await service.createAssertionChallenge('device-key', expected);

		await expect(service.verifyRequest({
			challengeId: challenge.id,
			keyId: 'device-key',
			assertion: Buffer.from('assertion'),
			request: { ...expected, pathname: '/v1/metals-monthly.json' }
		})).rejects.toMatchObject({ code: 'invalid_app_attest_assertion', status: 401 });
		expect(await store.getChallenge(challenge.id)).not.toBeNull();
	});

	it('rejects an unknown key before reading the protected request body', async () => {
		const service = new AppAttestAuthService({ store: new TestStore(), verifier: new TestVerifier() });
		let bodyWasRead = false;

		await expect(service.verifyRequest({
			challengeId: randomUUID(),
			keyId: 'unknown-key',
			assertion: Buffer.from('assertion'),
			request: async () => {
				bodyWasRead = true;
				throw new Error('body should not be read');
			}
		})).rejects.toMatchObject({ code: 'unknown_app_attest_key', status: 401 });
		expect(bodyWasRead).toBe(false);
	});
});
