import { describe, expect, test } from 'vitest';

import { loadAssetExtractionConfig } from './config';
import { pseudonymize } from './identity';

describe('asset extraction configuration and identities', () => {
	test('keeps the endpoint off without requiring an OpenAI secret', () => {
		expect(loadAssetExtractionConfig({ ASSET_EXTRACTION_ENABLED: 'false' })).toEqual({
			enabled: false
		});
	});

	test('requires a separate OpenAI key and a 256-bit HMAC secret when enabled', () => {
		const secret = Buffer.alloc(32, 7).toString('base64');
		expect(loadAssetExtractionConfig({
			ASSET_EXTRACTION_ENABLED: 'true',
			OPENAI_API_KEY: 'test-key',
			REDIS_URL: 'redis://redis:6379',
			ASSET_EXTRACTION_HMAC_SECRET: secret
		})).toEqual({
			enabled: true,
			openAIAPIKey: 'test-key',
			redisURL: 'redis://redis:6379',
			hmacSecret: Buffer.alloc(32, 7),
			redisPrefix: 'kara:asset-extraction'
		});

		expect(() => loadAssetExtractionConfig({
			ASSET_EXTRACTION_ENABLED: 'true',
			OPENAI_API_KEY: 'test-key',
			REDIS_URL: 'redis://redis:6379',
			ASSET_EXTRACTION_HMAC_SECRET: Buffer.alloc(16).toString('base64')
		})).toThrow('ASSET_EXTRACTION_HMAC_SECRET');
	});

	test('uses domain-separated HMAC pseudonyms', () => {
		const secret = Buffer.alloc(32, 9);
		const installation = pseudonymize(secret, 'installation', 'raw-key-id');
		const ip = pseudonymize(secret, 'ip', 'raw-key-id');

		expect(installation).toMatch(/^[a-f0-9]{64}$/);
		expect(installation).not.toContain('raw-key-id');
		expect(installation).not.toBe(ip);
		expect(pseudonymize(secret, 'installation', 'raw-key-id')).toBe(installation);
	});
});
