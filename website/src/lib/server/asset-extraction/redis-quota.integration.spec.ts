import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';

import { RedisAnalysisQuotaStore } from './redis-quota';

const redisURL = process.env.TEST_REDIS_URL;
const installationId = 'a'.repeat(64);
const ipId = 'b'.repeat(64);

describe.runIf(redisURL)('Redis asset-analysis quota store', () => {
	test('atomically enforces rolling minute, daily, concurrency and quarantine limits', async () => {
		const store = new RedisAnalysisQuotaStore(redisURL!, `kara:test:${randomUUID()}`);
		const now = Date.now();
		for (let index = 0; index < 10; index += 1) {
			expect(await store.recordAttempt({
				installationId, ipId, requestId: randomUUID(), nowMilliseconds: now + index
			})).toEqual({ kind: 'accepted' });
		}
		expect(await store.recordAttempt({
			installationId, ipId, requestId: randomUUID(), nowMilliseconds: now + 10
		})).toMatchObject({ kind: 'minute_limited' });

		for (let index = 0; index < 20; index += 1) {
			const token = randomUUID();
			expect(await store.reserve({
				installationId, ipId, requestId: token, nowMilliseconds: now + index
			})).toEqual({ kind: 'accepted', lockToken: token });
			await store.release(installationId, ipId, token);
		}
		expect(await store.reserve({
			installationId, ipId, requestId: randomUUID(), nowMilliseconds: now + 21
		})).toMatchObject({ kind: 'daily_limited' });

		const otherInstallation = 'c'.repeat(64);
		const otherIP = 'e'.repeat(64);
		const first = await store.reserve({
			installationId: otherInstallation, ipId: otherIP,
			requestId: 'first', nowMilliseconds: now
		});
		expect(first).toEqual({ kind: 'accepted', lockToken: 'first' });
		expect(await store.reserve({
			installationId: otherInstallation, ipId: otherIP,
			requestId: 'second', nowMilliseconds: now
		})).toMatchObject({ kind: 'concurrent' });
		await store.release(otherInstallation, otherIP, 'first');

		const concurrentIP = 'f'.repeat(64);
		for (let index = 0; index < 3; index += 1) {
			const token = `ip-lock-${index}`;
			expect(await store.reserve({
				installationId: `${(index + 10).toString(16).padStart(64, '0')}`,
				ipId: concurrentIP,
				requestId: token,
				nowMilliseconds: now
			})).toEqual({ kind: 'accepted', lockToken: token });
		}
		expect(await store.reserve({
			installationId: '1f'.padStart(64, '0'), ipId: concurrentIP,
			requestId: 'ip-lock-4', nowMilliseconds: now
		})).toMatchObject({ kind: 'ip_concurrent' });
		for (let index = 0; index < 3; index += 1) {
			await store.release(
				`${(index + 10).toString(16).padStart(64, '0')}`,
				concurrentIP,
				`ip-lock-${index}`
			);
		}

		const dailyIP = '9'.repeat(64);
		for (let index = 0; index < 100; index += 1) {
			const perIPInstallation = `${(index + 100).toString(16).padStart(64, '0')}`;
			const token = `ip-day-${index}`;
			expect(await store.reserve({
				installationId: perIPInstallation,
				ipId: dailyIP,
				requestId: token,
				nowMilliseconds: now + index
			})).toEqual({ kind: 'accepted', lockToken: token });
			await store.release(perIPInstallation, dailyIP, token);
		}
		expect(await store.reserve({
			installationId: 'ff'.padStart(64, '0'), ipId: dailyIP,
			requestId: 'ip-day-101', nowMilliseconds: now + 101
		})).toMatchObject({ kind: 'ip_daily_limited' });

		const abusiveInstallation = 'd'.repeat(64);
		let lastResult: unknown;
		for (let index = 0; index < 100; index += 1) {
			lastResult = await store.recordAttempt({
				installationId: abusiveInstallation,
				ipId: `${index.toString(16).padStart(64, '0')}`,
				requestId: randomUUID(),
				nowMilliseconds: now + index
			});
		}
		expect(lastResult).toMatchObject({ kind: 'quarantined', retryAfterSeconds: 604_800 });
		expect(await store.recordAttempt({
			installationId: abusiveInstallation, ipId, requestId: randomUUID(), nowMilliseconds: now + 101
		})).toMatchObject({ kind: 'quarantined' });

		const abusiveIP = '8'.repeat(64);
		for (let index = 0; index < 100; index += 1) {
			lastResult = await store.recordAttempt({
				installationId: `${(index + 1_000).toString(16).padStart(64, '0')}`,
				ipId: abusiveIP,
				requestId: randomUUID(),
				nowMilliseconds: now + index
			});
		}
		expect(lastResult).toMatchObject({ kind: 'quarantined', retryAfterSeconds: 604_800 });
		expect(await store.recordAttempt({
			installationId: '7'.repeat(64), ipId: abusiveIP,
			requestId: randomUUID(), nowMilliseconds: now + 101
		})).toMatchObject({ kind: 'quarantined' });
		expect(await store.reserve({
			installationId: '6'.repeat(64), ipId: abusiveIP,
			requestId: randomUUID(), nowMilliseconds: now + 101
		})).toMatchObject({ kind: 'quarantined' });
		await store.close();
	});
});
