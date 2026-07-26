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
	pricePaid: null,
	sellerName: null,
	storageLocationName: null,
	invoiceNumber: null,
	serialNumber: null,
	acquisitionMethod: null,
	tags: []
};

function candidate<Value>(
	value: Value,
	confidencePercent = 90,
	evidenceKind: 'visible_text' | 'visual_identification' | 'context_inference' = 'visible_text'
) {
	return { value, confidencePercent, evidenceKind };
}

describe('asset extraction output contract', () => {
	test('returns schema v2 candidates with per-field confidence and atomic money', () => {
		const model = modelSuggestionSchema.parse({
			...emptyModelSuggestion,
			weightGrams: candidate(100, 92),
			pricePaid: candidate({ amount: 1234.56, currencyCode: 'EUR' }, 96),
			tags: [candidate('Or d’investissement', 78, 'context_inference')]
		});

		expect(toPublicExtraction(model)).toEqual({
			schemaVersion: 2,
			suggestion: {
				...emptyModelSuggestion,
				weightGrams: candidate(100, 92),
				pricePaid: candidate({ minorUnits: 123456, currencyCode: 'EUR' }, 96),
				tags: [candidate('Or d’investissement', 78, 'context_inference')]
			}
		});
	});

	test('rejects impossible dates, unknown presets, extra keys and unsafe amounts', () => {
		for (const suggestion of [
			{ ...emptyModelSuggestion, purchaseDate: candidate('2026-02-30') },
			{ ...emptyModelSuggestion, presetId: candidate('invented-product') },
			{ ...emptyModelSuggestion, hidden: 'surprise' },
			{
				...emptyModelSuggestion,
				pricePaid: candidate({ amount: Number.MAX_SAFE_INTEGER, currencyCode: 'EUR' })
			}
		]) {
			expect(modelSuggestionSchema.safeParse(suggestion).success).toBe(false);
		}
	});

	test('requires valid confidence for every present candidate', () => {
		for (const confidencePercent of [-1, 0, 50.5, 101]) {
			expect(modelSuggestionSchema.safeParse({
				...emptyModelSuggestion,
				weightGrams: candidate(100, confidencePercent)
			}).success).toBe(false);
		}
		expect(modelSuggestionSchema.safeParse({
			...emptyModelSuggestion,
			weightGrams: { value: 100, evidenceKind: 'visible_text' }
		}).success).toBe(false);
	});

	test('rejects category or metal values that contradict the selected server preset', () => {
		expect(modelSuggestionSchema.safeParse({
			...emptyModelSuggestion,
			presetId: candidate('gold-bar-10g'),
			category: candidate('coin'),
			metal: candidate('silver')
		}).success).toBe(false);
	});

	test('requires every public property and rejects additions', () => {
		const response = toPublicExtraction(modelSuggestionSchema.parse(emptyModelSuggestion));
		expect(publicExtractionSchema.parse(response)).toEqual(response);
		expect(publicExtractionSchema.safeParse({
			...response,
			suggestion: { ...response.suggestion, prompt: 'ignored' }
		}).success).toBe(false);
	});
});
