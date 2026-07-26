import { createHmac } from 'node:crypto';
import type { BackendLogger } from '../logger';
import { logger as rootLogger } from '../logger';
import { RedisConnection } from '../redis-connection';

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;
const PSEUDONYM_PATTERN = /^[a-f0-9]{64}$/;

const LIMIT_SCRIPT = `
local now = tonumber(ARGV[1])
local requestId = ARGV[2]
local minuteWindow = tonumber(ARGV[3])
local minuteLimit = tonumber(ARGV[4])
local hourWindow = tonumber(ARGV[5])
local hourLimit = tonumber(ARGV[6])

redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now - minuteWindow)
redis.call('ZADD', KEYS[1], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[1], minuteWindow)

if hourLimit > 0 then
  redis.call('ZREMRANGEBYSCORE', KEYS[2], '-inf', now - hourWindow)
  redis.call('ZADD', KEYS[2], 'NX', now, requestId)
  redis.call('PEXPIRE', KEYS[2], hourWindow)
end

if redis.call('ZCARD', KEYS[1]) > minuteLimit then
  local oldest = redis.call('ZRANGE', KEYS[1], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + minuteWindow - now) + 999) / 1000))
  return 'limited|' .. retry
end

if hourLimit > 0 and redis.call('ZCARD', KEYS[2]) > hourLimit then
  local oldest = redis.call('ZRANGE', KEYS[2], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + hourWindow - now) + 999) / 1000))
  return 'limited|' .. retry
end
return 'accepted'
`;

export type AppAttestPublicEndpoint = 'challenge' | 'registration';
export type IPRateLimitDecision =
	| { kind: 'accepted' }
	| { kind: 'limited'; retryAfterSeconds: number };

export interface AppAttestIPRateLimitStore {
	ping(): Promise<void>;
	consume(input: {
		endpoint: AppAttestPublicEndpoint;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<IPRateLimitDecision>;
}

export class RedisAppAttestIPRateLimiter implements AppAttestIPRateLimitStore {
	readonly #redis: RedisConnection;
	readonly #prefix: string;

	constructor(
		url: string,
		prefix = 'kara:app-attest:ip-rate-limit',
		logger: Pick<BackendLogger, 'error' | 'info'> = rootLogger.child({
			component: 'app-attest.rate-limit.redis'
		})
	) {
		this.#prefix = prefix;
		this.#redis = new RedisConnection(url, logger, {
			unavailable: 'App Attest rate-limit Redis connection unavailable',
			recovered: 'App Attest rate-limit Redis connection recovered',
			ready: 'App Attest rate-limit Redis connection ready'
		});
	}

	async ping(): Promise<void> {
		await this.#redis.ping();
	}

	async close(): Promise<void> {
		await this.#redis.close();
	}

	async consume(input: {
		endpoint: AppAttestPublicEndpoint;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<IPRateLimitDecision> {
		if (!PSEUDONYM_PATTERN.test(input.ipId)) {
			throw new Error('App Attest IP identifiers must be HMAC pseudonyms');
		}
		const minuteLimit = input.endpoint === 'challenge' ? 30 : 5;
		const hourLimit = input.endpoint === 'registration' ? 20 : 0;
		const result = await this.#redis.execute((client) => client.eval(LIMIT_SCRIPT, {
			keys: [
				`${this.#prefix}:${input.endpoint}:${input.ipId}:minute`,
				`${this.#prefix}:${input.endpoint}:${input.ipId}:hour`
			],
			arguments: [
				String(input.nowMilliseconds), input.requestId,
				String(MINUTE_MS), String(minuteLimit), String(HOUR_MS), String(hourLimit)
			]
		}));
		if (result === 'accepted') return { kind: 'accepted' };
		if (typeof result === 'string' && result.startsWith('limited|')) {
			const retryAfterSeconds = Number(result.slice('limited|'.length));
			if (Number.isSafeInteger(retryAfterSeconds) && retryAfterSeconds > 0) {
				return { kind: 'limited', retryAfterSeconds };
			}
		}
		throw new Error('Redis returned an invalid App Attest rate-limit decision');
	}

}

export class AppAttestIPRateLimiter {
	constructor(
		private readonly secret: Buffer,
		private readonly store: AppAttestIPRateLimitStore
	) {}

	async ready(): Promise<void> {
		await this.store.ping();
	}

	async consume(input: {
		endpoint: AppAttestPublicEndpoint;
		clientAddress: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<IPRateLimitDecision> {
		const { clientAddress, ...request } = input;
		const ipId = createHmac('sha256', this.secret)
			.update('kara:app-attest:ip\0', 'utf8')
			.update(clientAddress, 'utf8')
			.digest('hex');
		return this.store.consume({ ...request, ipId });
	}
}
