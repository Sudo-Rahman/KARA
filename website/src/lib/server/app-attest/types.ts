export type AppAttestEnvironment = 'development' | 'production';
export type ChallengePurpose = 'registration' | 'assertion';

export interface RequestBinding {
	method: string;
	pathname: string;
	query: string;
	bodySHA256: string;
}

export interface ChallengeRecord {
	id: string;
	nonce: string;
	purpose: ChallengePurpose;
	keyId: string;
	request?: RequestBinding;
	createdAt: string;
	expiresAt: string;
}

export interface RegisteredAppAttestKey {
	keyId: string;
	publicKey: string;
	environment: AppAttestEnvironment;
	highSignCount: number;
	recentSignCounts: number[];
	createdAt: string;
}

export type RegistrationResult = 'registered' | 'missing_challenge' | 'challenge_mismatch';
export type AssertionConsumptionResult =
	| 'accepted'
	| 'missing_challenge'
	| 'unknown_key'
	| 'challenge_mismatch'
	| 'replayed';

export interface AssertionConsumption {
	challengeId: string;
	keyId: string;
	signCount: number;
	recentCounterWindow: number;
}

export interface AppAttestStore {
	ping(): Promise<void>;
	saveChallenge(challenge: ChallengeRecord): Promise<void>;
	getChallenge(id: string): Promise<ChallengeRecord | null>;
	getKey(keyId: string): Promise<RegisteredAppAttestKey | null>;
	consumeRegistration(
		challengeId: string,
		key: RegisteredAppAttestKey
	): Promise<RegistrationResult>;
	consumeAssertion(input: AssertionConsumption): Promise<AssertionConsumptionResult>;
}

export interface AttestationVerification {
	publicKey: string;
	environment: AppAttestEnvironment;
}

export interface AssertionVerification {
	signCount: number;
}

export interface AttestationVerifier {
	verifyAttestation(input: {
		attestation: Buffer;
		challenge: Buffer;
		keyId: string;
	}): AttestationVerification;
	verifyAssertion(input: {
		assertion: Buffer;
		payload: Buffer;
		publicKey: string;
		minimumSignCount: number;
	}): AssertionVerification;
}

export interface PublicChallenge {
	id: string;
	challenge: string;
	expiresAt: string;
}
