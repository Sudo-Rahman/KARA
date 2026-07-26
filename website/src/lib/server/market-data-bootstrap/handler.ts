import { createHash, randomUUID } from 'node:crypto';

import type { MetalsManifest } from '../metals-data/contracts';
import type { SpotCacheResult, SpotCacheStatus } from '../metals-spot/cache';
import { METALS, type Currency, type Metal } from '../metals-spot/contracts';
import { marketDataBootstrapSchema } from './contracts';
import type { BackendLogger } from '../logger';
import { errorSummary, logger as rootLogger } from '../logger';

const encoder = new TextEncoder();

class SpotRequestError extends Error {
	readonly metal: Metal;

	constructor(metal: Metal, cause: unknown) {
		super(`Spot request failed for ${metal}`, { cause });
		this.name = 'SpotRequestError';
		this.metal = metal;
	}
}

function jsonError(status: number, code: string, message: string): Response {
	const bytes = encoder.encode(JSON.stringify({ error: { code, message } }));
	return new Response(Buffer.from(bytes), {
		status,
		headers: {
			'Access-Control-Allow-Origin': '*',
			'Cache-Control': 'no-store',
			'Content-Length': String(bytes.byteLength),
			'Content-Type': 'application/json',
			'X-Content-Type-Options': 'nosniff'
		}
	});
}

function responseHeaders(bytes: Uint8Array): Headers {
	return new Headers({
		'Access-Control-Allow-Origin': '*',
		'Cache-Control': 'private, max-age=0, must-revalidate',
		'Content-Length': String(bytes.byteLength),
		'Content-Type': 'application/json',
		ETag: `"${createHash('sha256').update(bytes).digest('hex')}"`,
		'X-Content-Type-Options': 'nosniff'
	});
}

function matchesEtag(header: string | null, etag: string): boolean {
	if (header === null) return false;
	return header.split(',').some((candidate) => {
		const value = candidate.trim();
		return value === '*' || value === etag || value === `W/${etag}`;
	});
}

function aggregateCacheStatus(results: readonly SpotCacheResult[]): SpotCacheStatus {
	if (results.some(({ cacheStatus }) => cacheStatus === 'STALE')) return 'STALE';
	if (results.some(({ cacheStatus }) => cacheStatus === 'MISS')) return 'MISS';
	return 'HIT';
}

export interface MarketDataBootstrapProvider {
	currentManifest(): MetalsManifest;
	get(metal: Metal, currency: Currency): Promise<SpotCacheResult>;
}

export interface MarketDataBootstrapLogContext {
	logger?: Pick<BackendLogger, 'error' | 'warn'>;
	requestId?: string;
}

export async function handleMarketDataBootstrapRequest(
	request: Request,
	provider: MarketDataBootstrapProvider,
	context: MarketDataBootstrapLogContext = {}
): Promise<Response> {
	const requestId = context.requestId ?? randomUUID();
	const logger = context.logger ?? rootLogger.child({
		component: 'market-data-bootstrap',
		requestId
	});
	const manifest = provider.currentManifest();
	let results: SpotCacheResult[];
	try {
		results = await Promise.all(METALS.map(async (metal) => {
			try {
				return await provider.get(metal, 'EUR');
			} catch (error) {
				throw new SpotRequestError(metal, error);
			}
		}));
	} catch (error) {
		const failed = error instanceof SpotRequestError ? error : undefined;
		logger.error({
			error: errorSummary(failed?.cause ?? error),
			event: 'market_data_bootstrap.upstream_failed',
			metal: failed?.metal,
			currency: 'EUR',
			requestId
		}, 'Market data bootstrap failed while loading spot quotes');
		const response = jsonError(
			502,
			'SPOT_UNAVAILABLE',
			'Real-time metal price is temporarily unavailable'
		);
		response.headers.set('X-Request-Id', requestId);
		return response;
	}
	const payload = marketDataBootstrapSchema.parse({
		schemaVersion: 1,
		manifest,
		spots: results.map(({ quote }) => quote)
	});
	const bytes = encoder.encode(JSON.stringify(payload));
	const headers = responseHeaders(bytes);
	const cacheStatus = aggregateCacheStatus(results);
	headers.set('X-Cache', cacheStatus);
	if (cacheStatus === 'STALE') {
		logger.warn({
			event: 'market_data_bootstrap.stale_quotes_served',
			requestId
		}, 'Serving a market data bootstrap with stale spot quotes');
		headers.set('Warning', '110 - "Response is stale"');
	}

	if (matchesEtag(request.headers.get('if-none-match'), headers.get('etag')!)) {
		return new Response(null, { status: 304, headers });
	}
	if (request.method === 'HEAD') return new Response(null, { status: 200, headers });
	return new Response(Buffer.from(bytes), { status: 200, headers });
}
