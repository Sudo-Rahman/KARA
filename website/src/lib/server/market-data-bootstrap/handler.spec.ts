import { afterEach, describe, expect, test, vi } from 'vitest';

import fallbackManifest from '../metals-data/fallback/v1/manifest.json?raw';
import type { MetalsManifest } from '../metals-data/contracts';
import type { SpotCacheResult, SpotCacheStatus } from '../metals-spot/cache';
import type { Currency, Metal, SpotQuote } from '../metals-spot/contracts';
import {
	handleMarketDataBootstrapRequest,
	type MarketDataBootstrapProvider
} from './handler';

const manifest = JSON.parse(fallbackManifest) as MetalsManifest;

afterEach(() => {
	vi.restoreAllMocks();
});

function quote(metal: Metal): SpotQuote {
	return {
		schemaVersion: 1,
		metal,
		currency: 'EUR',
		price: {
			XAU: '3563.200000',
			XAG: '39.120000',
			XPT: '1400.000000',
			XPD: '1200.000000'
		}[metal],
		unit: { code: 'troy_ounce', grams: '31.1034768' },
		sourceUpdatedAt: '2026-07-25T12:00:00Z'
	};
}

function provider(cacheStatus: SpotCacheStatus = 'HIT'): MarketDataBootstrapProvider {
	return {
		currentManifest: vi.fn(() => manifest),
		get: vi.fn(async (metal: Metal, _currency: Currency): Promise<SpotCacheResult> => ({
			cacheStatus,
			quote: quote(metal)
		}))
	};
}

describe('handleMarketDataBootstrapRequest', () => {
	test('returns the current manifest and all four EUR quotes in canonical order', async () => {
		const source = provider();

		const response = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			source
		);

		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({
			schemaVersion: 1,
			manifest,
			spots: ['XAU', 'XAG', 'XPT', 'XPD'].map((metal) => quote(metal as Metal))
		});
		expect(source.get).toHaveBeenCalledTimes(4);
		expect(source.get).toHaveBeenNthCalledWith(1, 'XAU', 'EUR');
		expect(source.get).toHaveBeenNthCalledWith(2, 'XAG', 'EUR');
		expect(source.get).toHaveBeenNthCalledWith(3, 'XPT', 'EUR');
		expect(source.get).toHaveBeenNthCalledWith(4, 'XPD', 'EUR');
	});

	test('starts all four spot lookups before waiting for any result', async () => {
		const started: Metal[] = [];
		let release: (() => void) | undefined;
		const gate = new Promise<void>((resolve) => {
			release = resolve;
		});
		const source: MarketDataBootstrapProvider = {
			currentManifest: () => manifest,
			get: async (metal) => {
				started.push(metal);
				await gate;
				return { cacheStatus: 'MISS', quote: quote(metal) };
			}
		};

		const response = handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			source
		);
		await vi.waitFor(() => expect(started).toEqual(['XAU', 'XAG', 'XPT', 'XPD']));
		release?.();

		await expect(response).resolves.toHaveProperty('status', 200);
	});

	test('serves deterministic private JSON with a strong ETag', async () => {
		const response = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			provider()
		);
		const body = new Uint8Array(await response.arrayBuffer());

		expect(response.headers.get('content-type')).toBe('application/json');
		expect(response.headers.get('content-length')).toBe(String(body.byteLength));
		expect(response.headers.get('cache-control')).toBe('private, max-age=0, must-revalidate');
		expect(response.headers.get('access-control-allow-origin')).toBe('*');
		expect(response.headers.get('x-content-type-options')).toBe('nosniff');
		expect(response.headers.get('etag')).toMatch(/^"[0-9a-f]{64}"$/);

		const repeated = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			provider()
		);
		expect(repeated.headers.get('etag')).toBe(response.headers.get('etag'));
	});

	test('supports conditional GET and HEAD without returning a body', async () => {
		const url = 'https://kara.example/v1/market-data/bootstrap.json';
		const initial = await handleMarketDataBootstrapRequest(new Request(url), provider());
		const etag = initial.headers.get('etag')!;

		const notModified = await handleMarketDataBootstrapRequest(
			new Request(url, { headers: { 'If-None-Match': `"other", W/${etag}` } }),
			provider()
		);
		const head = await handleMarketDataBootstrapRequest(
			new Request(url, { method: 'HEAD' }),
			provider()
		);

		expect(notModified.status).toBe(304);
		expect(await notModified.text()).toBe('');
		expect(notModified.headers.get('etag')).toBe(etag);
		expect(head.status).toBe(200);
		expect(await head.text()).toBe('');
		expect(head.headers.get('etag')).toBe(etag);
		expect(head.headers.get('content-length')).toBe(initial.headers.get('content-length'));
	});

	test('reports the aggregate spot cache state and warns when any quote is stale', async () => {
		const statuses: Record<Metal, SpotCacheStatus> = {
			XAU: 'HIT',
			XAG: 'MISS',
			XPT: 'STALE',
			XPD: 'HIT'
		};
		const source: MarketDataBootstrapProvider = {
			currentManifest: () => manifest,
			get: async (metal) => ({ cacheStatus: statuses[metal], quote: quote(metal) })
		};

		const stale = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			source
		);
		const miss = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			provider('MISS')
		);
		const hit = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			provider('HIT')
		);

		expect(stale.headers.get('x-cache')).toBe('STALE');
		expect(stale.headers.get('warning')).toBe('110 - "Response is stale"');
		expect(miss.headers.get('x-cache')).toBe('MISS');
		expect(miss.headers.get('warning')).toBeNull();
		expect(hit.headers.get('x-cache')).toBe('HIT');
	});

	test('returns an atomic generic gateway error when one spot is unavailable', async () => {
		const source: MarketDataBootstrapProvider = {
			currentManifest: () => manifest,
			get: async (metal) => {
				if (metal === 'XPT') {
					throw new Error('upstream secret failure');
				}
				return { cacheStatus: 'HIT', quote: quote(metal) };
			}
		};
		const errorLog = vi.spyOn(console, 'error').mockImplementation(() => undefined);

		const response = await handleMarketDataBootstrapRequest(
			new Request('https://kara.example/v1/market-data/bootstrap.json'),
			source
		);
		const body = await response.text();

		expect(response.status).toBe(502);
		expect(JSON.parse(body)).toEqual({
			error: {
				code: 'SPOT_UNAVAILABLE',
				message: 'Real-time metal price is temporarily unavailable'
			}
		});
		expect(body).not.toContain('upstream secret failure');
		expect(response.headers.get('x-request-id')).toMatch(/^[0-9a-f-]{36}$/);
		expect(response.headers.get('cache-control')).toBe('no-store');
		expect(errorLog).toHaveBeenCalledWith(
			'[market-data-bootstrap] Gold API request failed',
			expect.objectContaining({
				currency: 'EUR',
				metal: 'XPT',
				requestId: response.headers.get('x-request-id')
			})
		);
	});
});
