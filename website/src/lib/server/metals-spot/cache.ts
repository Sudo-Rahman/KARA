import {
	goldApiQuoteSchema,
	type Currency,
	type Metal,
	type SpotQuote
} from './contracts';

const DEFAULT_BASE_URL = 'https://api.gold-api.com';
const DEFAULT_MAX_STALE_MS = 5 * 60_000;
const DEFAULT_TTL_MS = 60_000;
const DEFAULT_TIMEOUT_MS = 5_000;

export type SpotCacheStatus = 'HIT' | 'MISS' | 'STALE';

export interface SpotCacheResult {
	cacheStatus: SpotCacheStatus;
	quote: SpotQuote;
}

interface CacheEntry {
	expiresAt: number;
	isStale: boolean;
	quote: SpotQuote;
	staleUntil: number;
}

interface MetalsSpotCacheOptions {
	baseUrl?: string;
	fetcher?: typeof fetch;
	maxStaleMs?: number;
	now?: () => number;
	timeoutMs?: number;
	ttlMs?: number;
}

export class MetalsSpotCache {
	readonly #baseUrl: string;
	readonly #entries = new Map<string, CacheEntry>();
	readonly #fetcher: typeof fetch;
	readonly #inFlight = new Map<string, Promise<SpotCacheResult>>();
	readonly #maxStaleMs: number;
	readonly #now: () => number;
	readonly #timeoutMs: number;
	readonly #ttlMs: number;

	constructor(options: MetalsSpotCacheOptions = {}) {
		this.#baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, '');
		this.#fetcher = options.fetcher ?? fetch;
		this.#maxStaleMs = options.maxStaleMs ?? DEFAULT_MAX_STALE_MS;
		this.#now = options.now ?? Date.now;
		this.#timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
		this.#ttlMs = options.ttlMs ?? DEFAULT_TTL_MS;
	}

	async get(metal: Metal, currency: Currency): Promise<SpotCacheResult> {
		const key = `${metal}:${currency}`;
		const cached = this.#entries.get(key);
		if (cached !== undefined && this.#now() < cached.expiresAt) {
			return { cacheStatus: cached.isStale ? 'STALE' : 'HIT', quote: cached.quote };
		}
		const activeRequest = this.#inFlight.get(key);
		if (activeRequest !== undefined) return activeRequest;

		const request = this.#refresh(key, metal, currency).catch((error: unknown) => {
			if (cached !== undefined && this.#now() < cached.staleUntil) {
				cached.expiresAt = Math.min(this.#now() + this.#ttlMs, cached.staleUntil);
				cached.isStale = true;
				return { cacheStatus: 'STALE' as const, quote: cached.quote };
			}
			throw error;
		});
		this.#inFlight.set(key, request);
		try {
			return await request;
		} finally {
			if (this.#inFlight.get(key) === request) this.#inFlight.delete(key);
		}
	}

	async #refresh(key: string, metal: Metal, currency: Currency): Promise<SpotCacheResult> {
		const response = await this.#fetcher(`${this.#baseUrl}/price/${metal}/${currency}`, {
			headers: { Accept: 'application/json' },
			signal: AbortSignal.timeout(this.#timeoutMs)
		});
		if (!response.ok) throw new Error('Gold API request failed');

		const upstream = goldApiQuoteSchema.parse(await response.json());
		if (upstream.symbol !== metal || upstream.currency !== currency) {
			throw new Error('Gold API returned a different market');
		}

		const quote: SpotQuote = {
			schemaVersion: 1,
			metal,
			currency,
			price: upstream.price.toFixed(6),
			unit: { code: 'troy_ounce', grams: '31.1034768' },
			sourceUpdatedAt: upstream.updatedAt
		};
		const fetchedAt = this.#now();
		this.#entries.set(key, {
			expiresAt: fetchedAt + this.#ttlMs,
			isStale: false,
			quote,
			staleUntil: fetchedAt + this.#ttlMs + this.#maxStaleMs
		});
		return { cacheStatus: 'MISS', quote };
	}
}
