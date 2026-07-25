import { createHash } from 'node:crypto';
import { createClient } from 'redis';

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
	readonly #client: ReturnType<typeof createClient>;
	readonly #prefix: string;
	#connectPromise: Promise<void> | null = null;

	constructor(url: string, prefix = 'kara:app-attest') {
		this.#prefix = prefix;
		this.#client = createClient({ url });
		this.#client.on('error', (error) => {
			console.error('[app-attest] Redis unavailable', { name: error.name });
		});
	}

	async ping(): Promise<void> {
		await this.#ensureConnected();
		await this.#client.ping();
	}

	async close(): Promise<void> {
		if (this.#client.isOpen) await this.#client.close();
	}

	async saveChallenge(challenge: ChallengeRecord): Promise<void> {
		await this.#ensureConnected();
		const ttl = Math.max(1, new Date(challenge.expiresAt).getTime() - Date.now());
		await this.#client.pSetEx(this.#challengeKey(challenge.id), ttl, JSON.stringify(challenge));
	}

	async getChallenge(id: string): Promise<ChallengeRecord | null> {
		await this.#ensureConnected();
		return parseJSON<ChallengeRecord>(await this.#client.get(this.#challengeKey(id)));
	}

	async getKey(keyId: string): Promise<RegisteredAppAttestKey | null> {
		await this.#ensureConnected();
		return parseJSON<RegisteredAppAttestKey>(await this.#client.get(this.#registeredKey(keyId)));
	}

	async consumeRegistration(
		challengeId: string,
		key: RegisteredAppAttestKey
	): Promise<RegistrationResult> {
		await this.#ensureConnected();
		return await this.#client.eval(REGISTER_SCRIPT, {
			keys: [this.#challengeKey(challengeId), this.#registeredKey(key.keyId)],
			arguments: [key.keyId, JSON.stringify(key)]
		}) as RegistrationResult;
	}

	async consumeAssertion(input: AssertionConsumption): Promise<AssertionConsumptionResult> {
		await this.#ensureConnected();
		return await this.#client.eval(ASSERT_SCRIPT, {
			keys: [this.#challengeKey(input.challengeId), this.#registeredKey(input.keyId)],
			arguments: [input.keyId, String(input.signCount), String(input.recentCounterWindow)]
		}) as AssertionConsumptionResult;
	}

	async #ensureConnected(): Promise<void> {
		if (this.#client.isReady) return;
		if (!this.#connectPromise) {
			this.#connectPromise = this.#client.connect().then(() => undefined).finally(() => {
				this.#connectPromise = null;
			});
		}
		await this.#connectPromise;
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
