import { createHash } from 'node:crypto';

import type { SpotCacheResult } from './cache';
import {
	CURRENCIES,
	METALS,
	currencySchema,
	metalSchema,
	type Currency,
	type Metal
} from './contracts';

export interface SpotQuoteProvider {
	get(metal: Metal, currency: Currency): Promise<SpotCacheResult>;
}

function jsonHeaders(bytes: Uint8Array): Headers {
	return new Headers({
		'Access-Control-Allow-Origin': '*',
		'Cache-Control': 'public, max-age=0, must-revalidate',
		'Content-Length': String(bytes.byteLength),
		'Content-Type': 'application/json',
		'X-Content-Type-Options': 'nosniff'
	});
}

function jsonBytes(value: unknown): Uint8Array {
	return new TextEncoder().encode(JSON.stringify(value));
}

function jsonError(status: number, code: string, message: string): Response {
	const bytes = jsonBytes({ error: { code, message } });
	return new Response(Buffer.from(bytes), { status, headers: jsonHeaders(bytes) });
}

function matchesEtag(header: string | null, etag: string): boolean {
	if (header === null) return false;
	return header.split(',').some((candidate) => {
		const value = candidate.trim();
		return value === '*' || value === etag || value === `W/${etag}`;
	});
}

function normalized(value: string | null): string | undefined {
	const result = value?.trim().toUpperCase();
	return result === '' ? undefined : result;
}

export async function handleSpotRequest(
	request: Request,
	provider: SpotQuoteProvider
): Promise<Response> {
	const url = new URL(request.url);
	const metal = metalSchema.safeParse(normalized(url.searchParams.get('metal')));
	const currency = currencySchema.safeParse(normalized(url.searchParams.get('currency')));
	if (!metal.success || !currency.success) {
		return jsonError(
			400,
			'INVALID_PARAMETERS',
			`metal must be one of ${METALS.join(', ')} and currency one of ${CURRENCIES.join(', ')}`
		);
	}

	let result: SpotCacheResult;
	try {
		result = await provider.get(metal.data, currency.data);
	} catch {
		return jsonError(
			502,
			'SPOT_UNAVAILABLE',
			'Real-time metal price is temporarily unavailable'
		);
	}

	const bytes = jsonBytes(result.quote);
	const etag = `"${createHash('sha256').update(bytes).digest('hex')}"`;
	const headers = jsonHeaders(bytes);
	headers.set('ETag', etag);
	headers.set('X-Cache', result.cacheStatus);
	if (result.cacheStatus === 'STALE') {
		headers.set('Warning', '110 - "Response is stale"');
	}

	if (matchesEtag(request.headers.get('if-none-match'), etag)) {
		return new Response(null, { status: 304, headers });
	}
	if (request.method === 'HEAD') {
		return new Response(null, { status: 200, headers });
	}
	return new Response(Buffer.from(bytes), { status: 200, headers });
}

