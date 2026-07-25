import { verifyAssertion, verifyAttestation } from 'node-app-attest';

import type { AppAttestConfig } from './config';
import type { AttestationVerifier } from './types';

export class NodeAppAttestVerifier implements AttestationVerifier {
	constructor(private readonly config: Pick<AppAttestConfig, 'teamIdentifier' | 'bundleIdentifier' | 'environment'>) {}

	verifyAttestation(input: Parameters<AttestationVerifier['verifyAttestation']>[0]) {
		const result = verifyAttestation({
			attestation: input.attestation,
			challenge: input.challenge,
			keyId: input.keyId,
			bundleIdentifier: this.config.bundleIdentifier,
			teamIdentifier: this.config.teamIdentifier,
			allowDevelopmentEnvironment: this.config.environment === 'development'
		});
		if (result.environment !== this.config.environment) {
			throw new Error(`Unexpected App Attest environment: ${result.environment}`);
		}
		return { publicKey: String(result.publicKey), environment: result.environment };
	}

	verifyAssertion(input: Parameters<AttestationVerifier['verifyAssertion']>[0]) {
		const result = verifyAssertion({
			assertion: input.assertion,
			payload: input.payload,
			publicKey: input.publicKey,
			bundleIdentifier: this.config.bundleIdentifier,
			teamIdentifier: this.config.teamIdentifier,
			signCount: input.minimumSignCount
		});
		return { signCount: Number(result.signCount) };
	}
}
