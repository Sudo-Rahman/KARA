import { describe, expect, it } from 'vitest';

import { canonicalRequest, normalizeQuery } from './canonical';

describe('App Attest canonical requests', () => {
	it('normalizes query parameters independently of their incoming order', () => {
		expect(normalizeQuery(new URL('https://kara.test/v1/metals-spot.json?metal=XAU&currency=EUR')))
			.toBe('currency=EUR&metal=XAU');
	});

	it('uses RFC 3986 escaping shared with Foundation', () => {
		expect(normalizeQuery(new URL("https://kara.test/v1/test?value=!*'()")))
			.toBe('value=%21%2A%27%28%29');
	});

	it('produces the protocol payload shared with iOS', () => {
		expect(canonicalRequest({
			challenge: 'AQIDBA',
			method: 'get',
			pathname: '/v1/metals-spot.json',
			query: 'currency=EUR&metal=XAU',
			bodySHA256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
		})).toBe([
			'KARA-APP-ATTEST-V1',
			'AQIDBA',
			'GET',
			'/v1/metals-spot.json',
			'currency=EUR&metal=XAU',
			'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
		].join('\n'));
	});
});
