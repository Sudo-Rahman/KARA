import type { BackendLogger } from '../logger';
import { logger as rootLogger } from '../logger';
import { RedisConnection } from '../redis-connection';

const MINUTE_WINDOW_MS = 60_000;
const DAY_WINDOW_MS = 86_400_000;
const QUARANTINE_MS = 7 * DAY_WINDOW_MS;
const CONCURRENCY_LOCK_MS = 60_000;
const PSEUDONYM_PATTERN = /^[a-f0-9]{64}$/;

const ATTEMPT_SCRIPT = `
local ipQuarantineTTL = redis.call('PTTL', KEYS[6])
if ipQuarantineTTL > 0 then
  return 'quarantined|' .. math.floor((ipQuarantineTTL + 999) / 1000)
end
local installationQuarantineTTL = redis.call('PTTL', KEYS[3])
if installationQuarantineTTL > 0 then
  return 'quarantined|' .. math.floor((installationQuarantineTTL + 999) / 1000)
end

local now = tonumber(ARGV[1])
local requestId = ARGV[2]
local minuteWindow = tonumber(ARGV[3])
local dayWindow = tonumber(ARGV[4])
local quarantineDuration = tonumber(ARGV[5])

redis.call('ZREMRANGEBYSCORE', KEYS[2], '-inf', now - dayWindow)
redis.call('ZADD', KEYS[2], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[2], dayWindow)

redis.call('ZREMRANGEBYSCORE', KEYS[5], '-inf', now - dayWindow)
redis.call('ZADD', KEYS[5], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[5], dayWindow)

local installationDayCount = redis.call('ZCARD', KEYS[2])
local ipDayCount = redis.call('ZCARD', KEYS[5])
if installationDayCount >= 100 then
  redis.call('SET', KEYS[3], requestId, 'PX', quarantineDuration)
end
if ipDayCount >= 100 then
  redis.call('SET', KEYS[6], requestId, 'PX', quarantineDuration)
end
if installationDayCount >= 100 or ipDayCount >= 100 then
  return 'quarantined|' .. math.floor(quarantineDuration / 1000)
end

redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now - minuteWindow)
redis.call('ZADD', KEYS[1], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[1], minuteWindow)

redis.call('ZREMRANGEBYSCORE', KEYS[4], '-inf', now - minuteWindow)
redis.call('ZADD', KEYS[4], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[4], minuteWindow)

local installationCount = redis.call('ZCARD', KEYS[1])
if installationCount > 10 then
  local oldest = redis.call('ZRANGE', KEYS[1], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + minuteWindow - now) + 999) / 1000))
  return 'minute_limited|' .. retry
end

local ipCount = redis.call('ZCARD', KEYS[4])
if ipCount > 60 then
  local oldest = redis.call('ZRANGE', KEYS[4], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + minuteWindow - now) + 999) / 1000))
  return 'ip_limited|' .. retry
end

return 'accepted'
`;

const RESERVE_SCRIPT = `
local ipQuarantineTTL = redis.call('PTTL', KEYS[6])
if ipQuarantineTTL > 0 then
  return 'quarantined|' .. math.floor((ipQuarantineTTL + 999) / 1000)
end
local installationQuarantineTTL = redis.call('PTTL', KEYS[1])
if installationQuarantineTTL > 0 then
  return 'quarantined|' .. math.floor((installationQuarantineTTL + 999) / 1000)
end

local now = tonumber(ARGV[1])
local requestId = ARGV[2]
local dayWindow = tonumber(ARGV[3])
local lockDuration = tonumber(ARGV[4])
redis.call('ZREMRANGEBYSCORE', KEYS[2], '-inf', now - dayWindow)
redis.call('ZREMRANGEBYSCORE', KEYS[4], '-inf', now - dayWindow)
redis.call('ZREMRANGEBYSCORE', KEYS[5], '-inf', now)
if redis.call('ZCARD', KEYS[2]) >= 20 then
  local oldest = redis.call('ZRANGE', KEYS[2], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + dayWindow - now) + 999) / 1000))
  return 'daily_limited|' .. retry
end
if redis.call('ZCARD', KEYS[4]) >= 100 then
  local oldest = redis.call('ZRANGE', KEYS[4], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor(((tonumber(oldest[2]) + dayWindow - now) + 999) / 1000))
  return 'ip_daily_limited|' .. retry
end

local installationLockTTL = redis.call('PTTL', KEYS[3])
if installationLockTTL > 0 then
  return 'concurrent|' .. math.max(1, math.floor((installationLockTTL + 999) / 1000))
end
if redis.call('ZCARD', KEYS[5]) >= 3 then
  local oldestLock = redis.call('ZRANGE', KEYS[5], 0, 0, 'WITHSCORES')
  local retry = math.max(1, math.floor((tonumber(oldestLock[2]) - now + 999) / 1000))
  return 'ip_concurrent|' .. retry
end

if not redis.call('SET', KEYS[3], requestId, 'NX', 'PX', lockDuration) then
  local lockTTL = redis.call('PTTL', KEYS[3])
  return 'concurrent|' .. math.max(1, math.floor((lockTTL + 999) / 1000))
end
redis.call('ZADD', KEYS[2], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[2], dayWindow)
redis.call('ZADD', KEYS[4], 'NX', now, requestId)
redis.call('PEXPIRE', KEYS[4], dayWindow)
redis.call('ZADD', KEYS[5], 'NX', now + lockDuration, requestId)
redis.call('PEXPIRE', KEYS[5], lockDuration)
return 'accepted'
`;

const RELEASE_SCRIPT = `
local released = 0
if redis.call('GET', KEYS[1]) == ARGV[1] then
  released = released + redis.call('DEL', KEYS[1])
end
released = released + redis.call('ZREM', KEYS[2], ARGV[1])
if redis.call('ZCARD', KEYS[2]) == 0 then redis.call('DEL', KEYS[2]) end
return released
`;

export type AttemptDecision =
	| { kind: 'accepted' }
	| { kind: 'minute_limited' | 'ip_limited' | 'quarantined'; retryAfterSeconds: number };

export type ReservationDecision =
	| { kind: 'accepted'; lockToken: string }
	| {
		kind: 'daily_limited' | 'ip_daily_limited' | 'concurrent' | 'ip_concurrent' | 'quarantined';
		retryAfterSeconds: number;
	};

export interface AnalysisQuotaStore {
	ping(): Promise<void>;
	recordAttempt(input: {
		installationId: string;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<AttemptDecision>;
	reserve(input: {
		installationId: string;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<ReservationDecision>;
	release(installationId: string, ipId: string, lockToken: string): Promise<void>;
}

export class RedisAnalysisQuotaStore implements AnalysisQuotaStore {
	readonly #redis: RedisConnection;
	readonly #prefix: string;

	constructor(
		url: string,
		prefix = 'kara:asset-extraction',
		logger: Pick<BackendLogger, 'error' | 'info'> = rootLogger.child({
			component: 'asset-extraction.redis'
		})
	) {
		this.#prefix = prefix;
		this.#redis = new RedisConnection(url, logger, {
			unavailable: 'Asset extraction Redis connection unavailable',
			recovered: 'Asset extraction Redis connection recovered',
			ready: 'Asset extraction Redis connection ready'
		});
	}

	async ping(): Promise<void> {
		await this.#redis.ping();
	}

	async close(): Promise<void> {
		await this.#redis.close();
	}

	async recordAttempt(input: {
		installationId: string;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<AttemptDecision> {
		assertPseudonym(input.installationId);
		assertPseudonym(input.ipId);
		const result = await this.#redis.execute((client) => client.eval(ATTEMPT_SCRIPT, {
			keys: [
				this.#key(input.installationId, 'attempts:minute'),
				this.#key(input.installationId, 'attempts:day'),
				this.#key(input.installationId, 'quarantine'),
				`${this.#prefix}:ip:${input.ipId}:attempts:minute`,
				`${this.#prefix}:ip:${input.ipId}:attempts:day`,
				`${this.#prefix}:ip:${input.ipId}:quarantine`
			],
			arguments: [
				String(input.nowMilliseconds), input.requestId,
				String(MINUTE_WINDOW_MS), String(DAY_WINDOW_MS), String(QUARANTINE_MS)
			]
		}));
		return parseAttemptDecision(result);
	}

	async reserve(input: {
		installationId: string;
		ipId: string;
		requestId: string;
		nowMilliseconds: number;
	}): Promise<ReservationDecision> {
		assertPseudonym(input.installationId);
		assertPseudonym(input.ipId);
		const result = await this.#redis.execute((client) => client.eval(RESERVE_SCRIPT, {
			keys: [
				this.#key(input.installationId, 'quarantine'),
				this.#key(input.installationId, 'reservations:day'),
				this.#key(input.installationId, 'concurrent'),
				`${this.#prefix}:ip:${input.ipId}:reservations:day`,
				`${this.#prefix}:ip:${input.ipId}:concurrent`,
				`${this.#prefix}:ip:${input.ipId}:quarantine`
			],
			arguments: [
				String(input.nowMilliseconds), input.requestId,
				String(DAY_WINDOW_MS), String(CONCURRENCY_LOCK_MS)
			]
		}));
		const decision = parseReservationDecision(result);
		return decision.kind === 'accepted' ? { ...decision, lockToken: input.requestId } : decision;
	}

	async release(installationId: string, ipId: string, lockToken: string): Promise<void> {
		assertPseudonym(installationId);
		assertPseudonym(ipId);
		await this.#redis.execute((client) => client.eval(RELEASE_SCRIPT, {
			keys: [
				this.#key(installationId, 'concurrent'),
				`${this.#prefix}:ip:${ipId}:concurrent`
			],
			arguments: [lockToken]
		}));
	}

	#key(installationId: string, suffix: string): string {
		return `${this.#prefix}:installation:${installationId}:${suffix}`;
	}
}

function assertPseudonym(value: string): void {
	if (!PSEUDONYM_PATTERN.test(value)) {
		throw new Error('Quota identifiers must be HMAC pseudonyms');
	}
}

function parseAttemptDecision(value: unknown): AttemptDecision {
	const [kind, retry] = parseRedisDecision(value);
	if (kind === 'accepted') return { kind };
	if (kind === 'minute_limited' || kind === 'ip_limited' || kind === 'quarantined') {
		return { kind, retryAfterSeconds: retry };
	}
	throw new Error('Redis returned an unknown attempt decision');
}

type ParsedReservationDecision =
	| { kind: 'accepted' }
	| {
		kind: 'daily_limited' | 'ip_daily_limited' | 'concurrent' | 'ip_concurrent' | 'quarantined';
		retryAfterSeconds: number;
	};

function parseReservationDecision(value: unknown): ParsedReservationDecision {
	const [kind, retry] = parseRedisDecision(value);
	if (kind === 'accepted') return { kind };
	if (
		kind === 'daily_limited' || kind === 'ip_daily_limited' ||
		kind === 'concurrent' || kind === 'ip_concurrent' || kind === 'quarantined'
	) {
		return { kind, retryAfterSeconds: retry };
	}
	throw new Error('Redis returned an unknown reservation decision');
}

function parseRedisDecision(value: unknown): [string, number] {
	if (typeof value !== 'string') throw new Error('Redis returned a non-string quota decision');
	const [kind, retryText] = value.split('|');
	const retry = retryText === undefined ? 0 : Number(retryText);
	if (!Number.isSafeInteger(retry) || retry < 0) throw new Error('Redis returned an invalid retry delay');
	return [kind, retry];
}
