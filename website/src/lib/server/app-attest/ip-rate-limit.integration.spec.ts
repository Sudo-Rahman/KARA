import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';

import { RedisAppAttestIPRateLimiter } from './ip-rate-limit';

const redisURL = process.env.TEST_REDIS_URL;

describe.runIf(redisURL)('Redis App Attest public endpoint rate limits', () => {
	test('enforces challenge and registration IP windows atomically', async () => {
		const limiter = new RedisAppAttestIPRateLimiter(redisURL!, `kara:test:${randomUUID()}`);
		const now = Date.now();
		const challengeIP = 'a'.repeat(64);
		for (let index = 0; index < 30; index += 1) {
			expect(await limiter.consume({
				endpoint: 'challenge', ipId: challengeIP, requestId: randomUUID(), nowMilliseconds: now + index
			})).toEqual({ kind: 'accepted' });
		}
		expect(await limiter.consume({
			endpoint: 'challenge', ipId: challengeIP, requestId: randomUUID(), nowMilliseconds: now + 30
		})).toMatchObject({ kind: 'limited' });

		const registrationIP = 'b'.repeat(64);
		for (let index = 0; index < 5; index += 1) {
			expect(await limiter.consume({
				endpoint: 'registration', ipId: registrationIP,
				requestId: randomUUID(), nowMilliseconds: now + index
			})).toEqual({ kind: 'accepted' });
		}
		expect(await limiter.consume({
			endpoint: 'registration', ipId: registrationIP,
			requestId: randomUUID(), nowMilliseconds: now + 5
		})).toMatchObject({ kind: 'limited' });

		const hourlyIP = 'c'.repeat(64);
		for (let index = 0; index < 20; index += 1) {
			expect(await limiter.consume({
				endpoint: 'registration', ipId: hourlyIP,
				requestId: randomUUID(), nowMilliseconds: now + index * 61_000
			})).toEqual({ kind: 'accepted' });
		}
		expect(await limiter.consume({
			endpoint: 'registration', ipId: hourlyIP,
			requestId: randomUUID(), nowMilliseconds: now + 20 * 61_000
		})).toMatchObject({ kind: 'limited' });
		await limiter.close();
	});
});
