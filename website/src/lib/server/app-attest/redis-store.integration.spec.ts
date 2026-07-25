import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';

import { RedisAppAttestStore } from './redis-store';

const redisURL = process.env.TEST_REDIS_URL;

describe.runIf(redisURL)('Redis App Attest store', () => {
	it('atomically consumes registration and concurrent assertion counters', async () => {
		const store = new RedisAppAttestStore(redisURL!, `kara:test:${randomUUID()}`);
		const now = Date.now();
		const registrationChallenge = {
			id: randomUUID(), nonce: 'registration-nonce', purpose: 'registration' as const,
			keyId: 'device-key', createdAt: new Date(now).toISOString(),
			expiresAt: new Date(now + 300_000).toISOString()
		};
		await store.saveChallenge(registrationChallenge);
		expect(await store.consumeRegistration(registrationChallenge.id, {
			keyId: 'device-key', publicKey: 'public-key', environment: 'production',
			highSignCount: 0, recentSignCounts: [], createdAt: new Date(now).toISOString()
		})).toBe('registered');

		const makeChallenge = async () => {
			const challenge = {
				id: randomUUID(), nonce: randomUUID(), purpose: 'assertion' as const,
				keyId: 'device-key', createdAt: new Date(now).toISOString(),
				expiresAt: new Date(now + 300_000).toISOString()
			};
			await store.saveChallenge(challenge);
			return challenge;
		};
		const second = await makeChallenge();
		const first = await makeChallenge();
		expect(await store.consumeAssertion({
			challengeId: second.id, keyId: 'device-key', signCount: 2, recentCounterWindow: 64
		})).toBe('accepted');
		expect(await store.consumeAssertion({
			challengeId: first.id, keyId: 'device-key', signCount: 1, recentCounterWindow: 64
		})).toBe('accepted');

		const replay = await makeChallenge();
		expect(await store.consumeAssertion({
			challengeId: replay.id, keyId: 'device-key', signCount: 1, recentCounterWindow: 64
		})).toBe('replayed');
		await store.close();
	});
});
