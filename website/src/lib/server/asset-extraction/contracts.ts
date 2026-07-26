import { z } from 'zod';

import { ASSET_CATALOG, ASSET_PRESET_COMPATIBILITY, ASSET_PRESET_IDS } from './catalog';

const text = (maximum: number) => z.string().trim().min(1).max(maximum);
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const maximumMajorAmount = (Number.MAX_SAFE_INTEGER - 1) / 100;

export const evidenceKindSchema = z.enum([
	'visible_text',
	'visual_identification',
	'context_inference'
]);

const confidencePercentSchema = z.number().int().min(1).max(100);

function candidateSchema<Value extends z.ZodType>(value: Value) {
	return z.object({
		value,
		confidencePercent: confidencePercentSchema,
		evidenceKind: evidenceKindSchema
	}).strict().nullable();
}

const textCandidateSchema = (maximum: number) => candidateSchema(text(maximum));
const moneyValueSchema = z.object({
	amount: z.number().finite().nonnegative().max(maximumMajorAmount),
	currencyCode: z.enum(['EUR', 'USD', 'CHF', 'GBP'])
}).strict();

export const modelSuggestionWireSchema = z.object({
	name: textCandidateSchema(200),
	category: candidateSchema(z.enum(['bar', 'coin', 'jewelry', 'custom'])),
	presetId: candidateSchema(z.enum(ASSET_PRESET_IDS)),
	quantity: candidateSchema(z.number().int().min(1).max(10_000)),
	purchaseDate: candidateSchema(z.string().regex(datePattern)),
	metal: candidateSchema(z.enum(['gold', 'silver', 'platinum', 'palladium', 'other'])),
	weightGrams: candidateSchema(z.number().finite().positive().max(1_000_000_000)),
	metalKarat: candidateSchema(z.number().int().min(1).max(24)),
	finenessPermille: candidateSchema(z.number().finite().positive().max(1_000)),
	gemstoneCaratWeight: candidateSchema(z.number().finite().positive().max(1_000_000)),
	gemstoneClarity: textCandidateSchema(40),
	pricePaid: candidateSchema(moneyValueSchema),
	sellerName: textCandidateSchema(200),
	storageLocationName: textCandidateSchema(200),
	invoiceNumber: textCandidateSchema(200),
	serialNumber: textCandidateSchema(200),
	acquisitionMethod: candidateSchema(z.enum(['purchase', 'gift', 'inheritance', 'exchange', 'other']))
}).strict();

export const modelSuggestionSchema = modelSuggestionWireSchema.superRefine((suggestion, context) => {
	const purchaseDate = suggestion.purchaseDate?.value;
	if (purchaseDate !== undefined && !isCalendarDate(purchaseDate)) {
		context.addIssue({
			code: 'custom',
			path: ['purchaseDate', 'value'],
			message: 'purchaseDate is invalid'
		});
	}

	const presetID = suggestion.presetId?.value;
	if (presetID !== undefined) {
		const preset = ASSET_CATALOG.find((entry) => entry.id === presetID);
		if (preset && suggestion.category !== null && suggestion.category.value !== preset.category) {
			context.addIssue({
				code: 'custom',
				path: ['category', 'value'],
				message: 'category contradicts presetId'
			});
		}
		if (preset && preset.metal !== null && suggestion.metal !== null && suggestion.metal.value !== preset.metal) {
			context.addIssue({
				code: 'custom',
				path: ['metal', 'value'],
				message: 'metal contradicts presetId'
			});
		}
		if (preset && !matchesPresetNumber(suggestion.weightGrams?.value, preset.weightGrams)) {
			context.addIssue({
				code: 'custom',
				path: ['weightGrams', 'value'],
				message: 'weightGrams contradicts presetId'
			});
		}
		if (preset && !matchesPresetNumber(
			suggestion.finenessPermille?.value,
			preset.finenessPermille,
			ASSET_PRESET_COMPATIBILITY.finenessPermille.relativeTolerance,
			ASSET_PRESET_COMPATIBILITY.finenessPermille.absoluteTolerance
		)) {
			context.addIssue({
				code: 'custom',
				path: ['finenessPermille', 'value'],
				message: 'finenessPermille contradicts presetId'
			});
		}
		if (preset?.metalKarat !== null && suggestion.metalKarat !== null &&
			suggestion.metalKarat.value !== preset?.metalKarat) {
			context.addIssue({
				code: 'custom',
				path: ['metalKarat', 'value'],
				message: 'metalKarat contradicts presetId'
			});
		}
	}
});

function matchesPresetNumber(
	value: number | undefined,
	expected: number | null,
	relativeTolerance: number = ASSET_PRESET_COMPATIBILITY.weightGrams.relativeTolerance,
	absoluteTolerance: number = ASSET_PRESET_COMPATIBILITY.weightGrams.absoluteTolerance
): boolean {
	if (value === undefined || expected === null) return true;
	const tolerance = Math.max(absoluteTolerance, Math.abs(expected) * relativeTolerance);
	return Math.abs(value - expected) <= tolerance;
}

const publicMoneyCandidateSchema = candidateSchema(z.object({
	minorUnits: z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER),
	currencyCode: z.enum(['EUR', 'USD', 'CHF', 'GBP'])
}).strict());

const publicSuggestionSchema = modelSuggestionWireSchema.omit({ pricePaid: true }).extend({
	pricePaid: publicMoneyCandidateSchema
}).strict();

export const publicExtractionSchema = z.object({
	schemaVersion: z.literal(2),
	suggestion: publicSuggestionSchema
}).strict();

export type ModelSuggestion = z.infer<typeof modelSuggestionSchema>;
export type PublicExtraction = z.infer<typeof publicExtractionSchema>;

export function toPublicExtraction(value: ModelSuggestion): PublicExtraction {
	const { pricePaid, ...suggestion } = value;
	return publicExtractionSchema.parse({
		schemaVersion: 2,
		suggestion: {
			...suggestion,
			pricePaid: pricePaid === null
				? null
				: {
					...pricePaid,
					value: {
						minorUnits: majorToMinor(pricePaid.value.amount),
						currencyCode: pricePaid.value.currencyCode
					}
				}
		}
	});
}

function majorToMinor(value: number): number {
	const [coefficient, exponentText] = value.toString().toLowerCase().split('e');
	const exponent = exponentText === undefined ? 0 : Number(exponentText);
	const [whole, fraction = ''] = coefficient.split('.');
	const digits = `${whole}${fraction}`.replace(/^0+(?=\d)/, '');
	const decimalPlaces = fraction.length - exponent;
	const scale = 2 - decimalPlaces;
	let minor: bigint;
	if (scale >= 0) {
		minor = BigInt(digits) * 10n ** BigInt(scale);
	} else {
		const divisor = 10n ** BigInt(-scale);
		const raw = BigInt(digits);
		minor = raw / divisor;
		if ((raw % divisor) * 2n >= divisor) minor += 1n;
	}
	const result = Number(minor);
	if (!Number.isSafeInteger(result)) throw new Error('Minor-unit amount exceeds JSON integer precision');
	return result;
}

function isCalendarDate(value: string): boolean {
	const [year, month, day] = value.split('-').map(Number);
	const date = new Date(Date.UTC(year, month - 1, day));
	return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}
