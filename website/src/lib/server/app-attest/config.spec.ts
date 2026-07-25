import { describe, expect, it } from 'vitest';

import { loadAppAttestConfig } from './config';

describe('App Attest configuration', () => {
	it('loads the isolated Apple and Redis environment', () => {
		expect(loadAppAttestConfig({
			REDIS_URL: 'redis://redis:6379',
			APP_ATTEST_TEAM_ID: 'LBPZB5S37F',
			APP_ATTEST_BUNDLE_ID: 'com.karaprivate.KARA',
			APP_ATTEST_ENVIRONMENT: 'production'
		})).toEqual({
			redisURL: 'redis://redis:6379',
			teamIdentifier: 'LBPZB5S37F',
			bundleIdentifier: 'com.karaprivate.KARA',
			environment: 'production'
		});
	});

	it('rejects a backend that does not choose an Apple environment', () => {
		expect(() => loadAppAttestConfig({
			REDIS_URL: 'redis://redis:6379',
			APP_ATTEST_TEAM_ID: 'LBPZB5S37F',
			APP_ATTEST_BUNDLE_ID: 'com.karaprivate.KARA',
			APP_ATTEST_ENVIRONMENT: 'both'
		})).toThrow('APP_ATTEST_ENVIRONMENT must be development or production');
	});
});
