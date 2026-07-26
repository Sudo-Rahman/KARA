import { describe, expect, test, vi } from 'vitest';

import { AppAttestIPRateLimiter, type AppAttestIPRateLimitStore } from './ip-rate-limit';

describe('App Attest public endpoint IP limiter', () => {
	test('pseudonymizes the IP before the fail-closed Redis boundary', async () => {
		const store: AppAttestIPRateLimitStore = {
			ping: vi.fn(),
			consume: vi.fn().mockResolvedValue({ kind: 'accepted' })
		};
		const limiter = new AppAttestIPRateLimiter(Buffer.alloc(32, 3), store);

		await expect(limiter.consume({
			endpoint: 'registration',
			clientAddress: '203.0.113.10',
			requestId: 'request-id',
			nowMilliseconds: 1_000
		})).resolves.toEqual({ kind: 'accepted' });

		expect(store.consume).toHaveBeenCalledWith({
			endpoint: 'registration',
			ipId: expect.stringMatching(/^[a-f0-9]{64}$/),
			requestId: 'request-id',
			nowMilliseconds: 1_000
		});
		expect(JSON.stringify(vi.mocked(store.consume).mock.calls)).not.toContain('203.0.113.10');
	});

	test('does not turn a Redis failure into an accepted request', async () => {
		const store: AppAttestIPRateLimitStore = {
			ping: vi.fn(),
			consume: vi.fn().mockRejectedValue(new Error('redis unavailable'))
		};
		const limiter = new AppAttestIPRateLimiter(Buffer.alloc(32, 3), store);

		await expect(limiter.consume({
			endpoint: 'challenge',
			clientAddress: '203.0.113.10',
			requestId: 'request-id',
			nowMilliseconds: 1_000
		})).rejects.toThrow('redis unavailable');
	});
});
