import { env } from '$env/dynamic/private';

import { AppAttestIPRateLimiter, RedisAppAttestIPRateLimiter } from './ip-rate-limit';

let limiter: AppAttestIPRateLimiter | undefined;

export function appAttestIPRateLimiter(): AppAttestIPRateLimiter {
	if (!limiter) {
		const redisURL = required('REDIS_URL');
		const secret = decodeSecret(required('APP_ATTEST_RATE_LIMIT_HMAC_SECRET'));
		const prefix = env.APP_ATTEST_RATE_LIMIT_REDIS_PREFIX?.trim() || 'kara:app-attest:ip-rate-limit';
		if (!/^[a-z0-9:-]{1,100}$/i.test(prefix)) {
			throw new Error('APP_ATTEST_RATE_LIMIT_REDIS_PREFIX is invalid');
		}
		limiter = new AppAttestIPRateLimiter(
			secret,
			new RedisAppAttestIPRateLimiter(redisURL, prefix)
		);
	}
	return limiter;
}

function required(name: string): string {
	const value = env[name]?.trim();
	if (!value) throw new Error(`${name} is required`);
	return value;
}

function decodeSecret(encoded: string): Buffer {
	if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) {
		throw new Error('APP_ATTEST_RATE_LIMIT_HMAC_SECRET must be canonical base64');
	}
	const secret = Buffer.from(encoded, 'base64');
	if (secret.length < 32 || secret.toString('base64') !== encoded) {
		throw new Error('APP_ATTEST_RATE_LIMIT_HMAC_SECRET must contain at least 256 bits');
	}
	return secret;
}
