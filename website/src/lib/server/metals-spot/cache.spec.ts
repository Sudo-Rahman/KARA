import { describe, expect, test, vi } from 'vitest';

import { MetalsSpotCache } from './cache';

function goldApiResponse(
	price = 4165.200195,
	symbol: 'XAU' | 'XAG' | 'XPT' | 'XPD' = 'XAU',
	currency: 'EUR' | 'USD' = 'EUR'
): Response {
	return Response.json({
		currency,
		currencySymbol: currency === 'EUR' ? '€' : '$',
		exchangeRate: 0.86,
		name: 'Gold',
		price,
		symbol,
		updatedAt: '2026-07-20T12:34:56Z',
		updatedAtReadable: 'a few seconds ago'
	});
}

describe('MetalsSpotCache', () => {
	test('returns a stable Kara quote and reuses it for one minute', async () => {
		let now = 1_000_000;
		const fetcher = vi.fn<typeof fetch>().mockResolvedValue(goldApiResponse());
		const cache = new MetalsSpotCache({ fetcher, now: () => now });

		const first = await cache.get('XAU', 'EUR');
		now += 59_999;
		const second = await cache.get('XAU', 'EUR');

		expect(first).toEqual({
			cacheStatus: 'MISS',
			quote: {
				schemaVersion: 1,
				metal: 'XAU',
				currency: 'EUR',
				price: '4165.200195',
				unit: { code: 'troy_ounce', grams: '31.1034768' },
				sourceUpdatedAt: '2026-07-20T12:34:56Z'
			}
		});
		expect(second).toEqual({ ...first, cacheStatus: 'HIT' });
		expect(fetcher).toHaveBeenCalledTimes(1);
		expect(fetcher).toHaveBeenCalledWith(
			'https://api.gold-api.com/price/XAU/EUR',
			expect.objectContaining({
				headers: { Accept: 'application/json' },
				signal: expect.any(AbortSignal)
			})
		);
	});

	test('coalesces concurrent requests for the same metal and currency', async () => {
		let release: ((response: Response) => void) | undefined;
		const pending = new Promise<Response>((resolve) => {
			release = resolve;
		});
		const fetcher = vi.fn<typeof fetch>().mockReturnValue(pending);
		const cache = new MetalsSpotCache({ fetcher });

		const first = cache.get('XAU', 'EUR');
		const second = cache.get('XAU', 'EUR');
		release?.(goldApiResponse());

		await expect(Promise.all([first, second])).resolves.toEqual([
			expect.objectContaining({ cacheStatus: 'MISS' }),
			expect.objectContaining({ cacheStatus: 'MISS' })
		]);
		expect(fetcher).toHaveBeenCalledTimes(1);
	});

	test('serves the last quote temporarily when a refresh fails', async () => {
		let now = 1_000_000;
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(goldApiResponse())
			.mockRejectedValueOnce(new Error('offline'));
		const cache = new MetalsSpotCache({ fetcher, now: () => now });

		const current = await cache.get('XAU', 'EUR');
		now += 60_000;

		await expect(cache.get('XAU', 'EUR')).resolves.toEqual({
			cacheStatus: 'STALE',
			quote: current.quote
		});
		await expect(cache.get('XAU', 'EUR')).resolves.toMatchObject({ cacheStatus: 'STALE' });
		expect(fetcher).toHaveBeenCalledTimes(2);
	});

	test('refreshes the quote when the one-minute cache expires', async () => {
		let now = 1_000_000;
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(goldApiResponse(4000))
			.mockResolvedValueOnce(goldApiResponse(4100));
		const cache = new MetalsSpotCache({ fetcher, now: () => now });

		expect((await cache.get('XAU', 'EUR')).quote.price).toBe('4000.000000');
		now += 60_000;
		expect((await cache.get('XAU', 'EUR')).quote.price).toBe('4100.000000');
		expect(fetcher).toHaveBeenCalledTimes(2);
	});

	test('keeps independent cache entries for each metal and currency', async () => {
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(goldApiResponse())
			.mockResolvedValueOnce(goldApiResponse(37.5, 'XAG', 'USD'));
		const cache = new MetalsSpotCache({ fetcher });

		await cache.get('XAU', 'EUR');
		const silver = await cache.get('XAG', 'USD');

		expect(silver.quote).toMatchObject({
			metal: 'XAG',
			currency: 'USD',
			price: '37.500000'
		});
		expect(fetcher).toHaveBeenCalledTimes(2);
	});

	test('stops serving a stale quote after the configured grace period', async () => {
		let now = 1_000_000;
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(goldApiResponse())
			.mockRejectedValue(new Error('offline'));
		const cache = new MetalsSpotCache({ fetcher, maxStaleMs: 120_000, now: () => now });

		await cache.get('XAU', 'EUR');
		now += 60_000;
		await expect(cache.get('XAU', 'EUR')).resolves.toMatchObject({ cacheStatus: 'STALE' });
		now += 120_000;
		await expect(cache.get('XAU', 'EUR')).rejects.toThrow('offline');
	});
});
