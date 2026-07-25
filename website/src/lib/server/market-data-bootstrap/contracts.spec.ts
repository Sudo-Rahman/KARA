import { describe, expect, test } from 'vitest';

import fallbackManifest from '../metals-data/fallback/v1/manifest.json?raw';
import { marketDataBootstrapSchema } from './contracts';

function spot(metal: 'XAU' | 'XAG' | 'XPT' | 'XPD') {
	return {
		schemaVersion: 1,
		metal,
		currency: 'EUR',
		price: '1234.000000',
		unit: { code: 'troy_ounce', grams: '31.1034768' },
		sourceUpdatedAt: '2026-07-25T12:00:00Z'
	};
}

describe('marketDataBootstrapSchema', () => {
	test('accepts one EUR quote for every supported metal in canonical order', () => {
		const value = {
			schemaVersion: 1,
			manifest: JSON.parse(fallbackManifest),
			spots: ['XAU', 'XAG', 'XPT', 'XPD'].map((metal) =>
				spot(metal as 'XAU' | 'XAG' | 'XPT' | 'XPD'))
		};

		expect(marketDataBootstrapSchema.parse(value)).toEqual(value);
	});

	test('rejects a missing, duplicated, out-of-order, or non-EUR quote', () => {
		const valid = {
			schemaVersion: 1,
			manifest: JSON.parse(fallbackManifest),
			spots: ['XAU', 'XAG', 'XPT', 'XPD'].map((metal) =>
				spot(metal as 'XAU' | 'XAG' | 'XPT' | 'XPD'))
		};

		expect(marketDataBootstrapSchema.safeParse({ ...valid, spots: valid.spots.slice(0, 3) }).success)
			.toBe(false);
		expect(marketDataBootstrapSchema.safeParse({
			...valid,
			spots: [valid.spots[1], valid.spots[0], valid.spots[2], valid.spots[3]]
		}).success).toBe(false);
		expect(marketDataBootstrapSchema.safeParse({
			...valid,
			spots: valid.spots.map((value, index) => index === 0 ? { ...value, currency: 'USD' } : value)
		}).success).toBe(false);
	});
});
