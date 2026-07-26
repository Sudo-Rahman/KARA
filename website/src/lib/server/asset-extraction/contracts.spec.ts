import { describe, expect, test } from 'vitest';

import {
	modelSuggestionSchema,
	publicExtractionSchema,
	toPublicExtraction
} from './contracts';

const emptyModelSuggestion = {
	name: null,
	category: null,
	presetId: null,
	quantity: null,
	purchaseDate: null,
	metal: null,
	weightGrams: null,
	metalKarat: null,
	finenessPermille: null,
	gemstoneCaratWeight: null,
	gemstoneClarity: null,
	pricePaidAmount: null,
	currencyCode: null,
	sellerName: null,
	storageLocationName: null,
	invoiceNumber: null,
	serialNumber: null
};

describe('asset extraction output contract', () => {
	test('converts a validated major-unit amount to deterministic minor units', () => {
		const model = modelSuggestionSchema.parse({
			...emptyModelSuggestion,
			name: 'Lingot 100 g',
			category: 'bar',
			presetId: 'gold-bar-100g',
			purchaseDate: '2026-02-28',
			pricePaidAmount: 1234.56,
			currencyCode: 'EUR',
			serialNumber: 'A-001'
		});

		expect(toPublicExtraction(model)).toEqual({
			schemaVersion: 1,
			suggestion: {
				name: 'Lingot 100 g',
				category: 'bar',
				presetId: 'gold-bar-100g',
				quantity: null,
				purchaseDate: '2026-02-28',
				metal: null,
				weightGrams: null,
				metalKarat: null,
				finenessPermille: null,
				gemstoneCaratWeight: null,
				gemstoneClarity: null,
				pricePaidMinorUnits: 123456,
				currencyCode: 'EUR',
				sellerName: null,
				storageLocationName: null,
				invoiceNumber: null,
				serialNumber: 'A-001'
			}
		});
	});

	test('rejects impossible dates, unknown presets, extra keys and unsafe amounts', () => {
		for (const candidate of [
			{ ...emptyModelSuggestion, purchaseDate: '2026-02-30' },
			{ ...emptyModelSuggestion, presetId: 'invented-product' },
			{ ...emptyModelSuggestion, hidden: 'surprise' },
			{ ...emptyModelSuggestion, pricePaidAmount: Number.MAX_SAFE_INTEGER, currencyCode: 'EUR' }
		]) {
			expect(modelSuggestionSchema.safeParse(candidate).success).toBe(false);
		}
	});

	test('rejects category or metal values that contradict the selected server preset', () => {
		expect(modelSuggestionSchema.safeParse({
			...emptyModelSuggestion,
			presetId: 'gold-bar-10g',
			category: 'coin',
			metal: 'silver'
		}).success).toBe(false);
	});

	test('requires every nullable public property and rejects additions', () => {
		const response = toPublicExtraction(modelSuggestionSchema.parse(emptyModelSuggestion));
		expect(publicExtractionSchema.parse(response)).toEqual(response);
		expect(publicExtractionSchema.safeParse({
			...response,
			suggestion: { ...response.suggestion, prompt: 'ignored' }
		}).success).toBe(false);
	});
});
