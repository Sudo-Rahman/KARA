import { describe, expect, test, vi } from 'vitest';

import { handleSpotRequest, type SpotQuoteProvider } from './handler';

const quote = {
	schemaVersion: 1 as const,
	metal: 'XAU' as const,
	currency: 'EUR' as const,
	price: '4165.200195',
	unit: { code: 'troy_ounce' as const, grams: '31.1034768' as const },
	sourceUpdatedAt: '2026-07-20T12:34:56Z'
};

describe('handleSpotRequest', () => {
	test('serves a validated quote using normalized query parameters', async () => {
		const provider: SpotQuoteProvider = {
			get: vi.fn().mockResolvedValue({ cacheStatus: 'MISS', quote })
		};
		const request = new Request(
			'https://kara.example/v1/metals-spot.json?metal=xau&currency=eur'
		);

		const response = await handleSpotRequest(request, provider);

		expect(response.status).toBe(200);
		expect(response.headers.get('content-type')).toBe('application/json');
		expect(response.headers.get('cache-control')).toBe('public, max-age=0, must-revalidate');
		expect(response.headers.get('access-control-allow-origin')).toBe('*');
		expect(response.headers.get('x-content-type-options')).toBe('nosniff');
		expect(response.headers.get('x-cache')).toBe('MISS');
		expect(response.headers.get('etag')).toMatch(/^"[0-9a-f]{64}"$/);
		expect(await response.json()).toEqual(quote);
		expect(provider.get).toHaveBeenCalledWith('XAU', 'EUR');
	});

	test('rejects unsupported parameters without contacting the provider', async () => {
		const provider: SpotQuoteProvider = { get: vi.fn() };
		const request = new Request(
			'https://kara.example/v1/metals-spot.json?metal=BTC&currency=EUR'
		);

		const response = await handleSpotRequest(request, provider);

		expect(response.status).toBe(400);
		expect(await response.json()).toMatchObject({ error: { code: 'INVALID_PARAMETERS' } });
		expect(provider.get).not.toHaveBeenCalled();
	});

	test('supports HEAD and conditional GET with the quote ETag', async () => {
		const provider: SpotQuoteProvider = {
			get: vi.fn().mockResolvedValue({ cacheStatus: 'HIT', quote })
		};
		const url = 'https://kara.example/v1/metals-spot.json?metal=XAU&currency=EUR';
		const head = await handleSpotRequest(new Request(url, { method: 'HEAD' }), provider);
		const etag = head.headers.get('etag')!;
		const notModified = await handleSpotRequest(
			new Request(url, { headers: { 'If-None-Match': etag } }),
			provider
		);

		expect(head.status).toBe(200);
		expect(await head.text()).toBe('');
		expect(notModified.status).toBe(304);
		expect(await notModified.text()).toBe('');
	});

	test('marks a fallback quote as stale only through HTTP headers', async () => {
		const provider: SpotQuoteProvider = {
			get: vi.fn().mockResolvedValue({ cacheStatus: 'STALE', quote })
		};
		const request = new Request(
			'https://kara.example/v1/metals-spot.json?metal=XAU&currency=EUR'
		);

		const response = await handleSpotRequest(request, provider);

		expect(response.headers.get('x-cache')).toBe('STALE');
		expect(response.headers.get('warning')).toBe('110 - "Response is stale"');
		expect(await response.json()).toEqual(quote);
	});

	test('returns a generic gateway error when no quote is available', async () => {
		const provider: SpotQuoteProvider = {
			get: vi.fn().mockRejectedValue(new Error('secret upstream details'))
		};
		const request = new Request(
			'https://kara.example/v1/metals-spot.json?metal=XAU&currency=EUR'
		);

		const response = await handleSpotRequest(request, provider);
		const body = await response.text();

		expect(response.status).toBe(502);
		expect(body).toContain('SPOT_UNAVAILABLE');
		expect(body).not.toContain('secret upstream details');
	});
});
