import { createHash } from 'node:crypto';
import type { BackendLogger } from '../logger';
import { logger as rootLogger } from '../logger';
import { RedisConnection } from '../redis-connection';

import type {
	AppAttestStore,
	AssertionConsumption,
	AssertionConsumptionResult,
	ChallengeRecord,
	RegisteredAppAttestKey,
	RegistrationResult
} from './types';

const REGISTER_SCRIPT = `
local challengeRaw = redis.call('GET', KEYS[1])
if not challengeRaw then return 'missing_challenge' end
local challenge = cjson.decode(challengeRaw)
if challenge.purpose ~= 'registration' or challenge.keyId ~= ARGV[1] then
  return 'challenge_mismatch'
end
if redis.call('EXISTS', KEYS[2]) == 0 then
  redis.call('SET', KEYS[2], ARGV[2])
end
redis.call('DEL', KEYS[1])
return 'registered'
`;

const ASSERT_SCRIPT = `
local challengeRaw = redis.call('GET', KEYS[1])
if not challengeRaw then return 'missing_challenge' end
local challenge = cjson.decode(challengeRaw)
if challenge.purpose ~= 'assertion' or challenge.keyId ~= ARGV[1] then
  return 'challenge_mismatch'
end
local keyRaw = redis.call('GET', KEYS[2])
if not keyRaw then return 'unknown_key' end
local key = cjson.decode(keyRaw)
local signCount = tonumber(ARGV[2])
local window = tonumber(ARGV[3])
local high = tonumber(key.highSignCount) or 0
if signCount <= 0 or signCount <= high - window then return 'replayed' end
local recent = key.recentSignCounts or {}
for _, value in ipairs(recent) do
  if tonumber(value) == signCount then return 'replayed' end
end
if signCount > high then high = signCount end
local nextRecent = {}
for _, value in ipairs(recent) do
  if tonumber(value) > high - window then table.insert(nextRecent, tonumber(value)) end
end
table.insert(nextRecent, signCount)
key.highSignCount = high
key.recentSignCounts = nextRecent
redis.call('SET', KEYS[2], cjson.encode(key))
redis.call('DEL', KEYS[1])
return 'accepted'
`;

export class RedisAppAttestStore implements AppAttestStore {
	readonly #redis: RedisConnection;
	readonly #prefix: string;

	constructor(
		url: string,
		prefix = 'kara:app-attest',
		logger: Pick<BackendLogger, 'error' | 'info'> = rootLogger.child({ component: 'app-attest.redis' })
	) {
		this.#prefix = prefix;
		this.#redis = new RedisConnection(url, logger, {
			unavailable: 'App Attest Redis connection unavailable',
			recovered: 'App Attest Redis connection recovered',
			ready: 'App Attest Redis connection ready'
		});
	}

	async ping(): Promise<void> {
		await this.#redis.ping();
	}

	async close(): Promise<void> {
		await this.#redis.close();
	}

	async saveChallenge(challenge: ChallengeRecord): Promise<void> {
		const ttl = Math.max(1, new Date(challenge.expiresAt).getTime() - Date.now());
		await this.#redis.execute((client) =>
			client.pSetEx(this.#challengeKey(challenge.id), ttl, JSON.stringify(challenge))
		);
	}

	async getChallenge(id: string): Promise<ChallengeRecord | null> {
		return parseJSON<ChallengeRecord>(
			await this.#redis.execute((client) => client.get(this.#challengeKey(id)))
		);
	}

	async getKey(keyId: string): Promise<RegisteredAppAttestKey | null> {
		return parseJSON<RegisteredAppAttestKey>(
			await this.#redis.execute((client) => client.get(this.#registeredKey(keyId)))
		);
	}

	async consumeRegistration(
		challengeId: string,
		key: RegisteredAppAttestKey
	): Promise<RegistrationResult> {
		return await this.#redis.execute((client) => client.eval(REGISTER_SCRIPT, {
			keys: [this.#challengeKey(challengeId), this.#registeredKey(key.keyId)],
			arguments: [key.keyId, JSON.stringify(key)]
		})) as RegistrationResult;
	}

	async consumeAssertion(input: AssertionConsumption): Promise<AssertionConsumptionResult> {
		return await this.#redis.execute((client) => client.eval(ASSERT_SCRIPT, {
			keys: [this.#challengeKey(input.challengeId), this.#registeredKey(input.keyId)],
			arguments: [input.keyId, String(input.signCount), String(input.recentCounterWindow)]
		})) as AssertionConsumptionResult;
	}

	#challengeKey(id: string): string {
		return `${this.#prefix}:challenges:${id}`;
	}

	#registeredKey(keyId: string): string {
		const digest = createHash('sha256').update(keyId).digest('hex');
		return `${this.#prefix}:keys:${digest}`;
	}
}

function parseJSON<T>(value: string | null): T | null {
	return value === null ? null : JSON.parse(value) as T;
}
