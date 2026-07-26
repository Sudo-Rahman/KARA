import { z } from 'zod';

import { ASSET_CATALOG, ASSET_PRESET_IDS } from './catalog';

const optionalText = (maximum: number) => z.string().trim().min(1).max(maximum).nullable();
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const maximumMajorAmount = (Number.MAX_SAFE_INTEGER - 1) / 100;

export const modelSuggestionWireSchema = z.object({
	name: optionalText(200),
	category: z.enum(['bar', 'coin', 'jewelry', 'custom']).nullable(),
	presetId: z.enum(ASSET_PRESET_IDS).nullable(),
	quantity: z.number().int().min(1).max(10_000).nullable(),
	purchaseDate: z.string().regex(datePattern).nullable(),
	metal: z.enum(['gold', 'silver', 'platinum', 'palladium', 'other']).nullable(),
	weightGrams: z.number().finite().positive().max(1_000_000_000).nullable(),
	metalKarat: z.number().int().min(1).max(24).nullable(),
	finenessPermille: z.number().finite().positive().max(1_000).nullable(),
	gemstoneCaratWeight: z.number().finite().positive().max(1_000_000).nullable(),
	gemstoneClarity: optionalText(40),
	pricePaidAmount: z.number().finite().nonnegative().max(maximumMajorAmount).nullable(),
	currencyCode: z.enum(['EUR', 'USD', 'CHF', 'GBP']).nullable(),
	sellerName: optionalText(200),
	storageLocationName: optionalText(200),
	invoiceNumber: optionalText(200),
	serialNumber: optionalText(200)
}).strict();

export const modelSuggestionSchema = modelSuggestionWireSchema.superRefine((value, context) => {
	if (value.purchaseDate !== null && !isCalendarDate(value.purchaseDate)) {
		context.addIssue({ code: 'custom', path: ['purchaseDate'], message: 'purchaseDate is invalid' });
	}
	if ((value.pricePaidAmount === null) !== (value.currencyCode === null)) {
		context.addIssue({
			code: 'custom',
			path: ['pricePaidAmount'],
			message: 'pricePaidAmount and currencyCode must either both be set or both be null'
		});
	}
	if (value.presetId !== null) {
		const preset = ASSET_CATALOG.find(([id]) => id === value.presetId);
		if (preset && value.category !== null && value.category !== preset[2]) {
			context.addIssue({
				code: 'custom',
				path: ['category'],
				message: 'category contradicts presetId'
			});
		}
		if (preset && preset[3] !== null && value.metal !== null && value.metal !== preset[3]) {
			context.addIssue({
				code: 'custom',
				path: ['metal'],
				message: 'metal contradicts presetId'
			});
		}
	}
});

const publicSuggestionSchema = modelSuggestionWireSchema.omit({ pricePaidAmount: true }).extend({
	pricePaidMinorUnits: z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER).nullable()
}).strict();

export const publicExtractionSchema = z.object({
	schemaVersion: z.literal(1),
	suggestion: publicSuggestionSchema
}).strict();

export type ModelSuggestion = z.infer<typeof modelSuggestionSchema>;
export type PublicExtraction = z.infer<typeof publicExtractionSchema>;

export function toPublicExtraction(value: ModelSuggestion): PublicExtraction {
	const { pricePaidAmount, ...suggestion } = value;
	return publicExtractionSchema.parse({
		schemaVersion: 1,
		suggestion: {
			...suggestion,
			pricePaidMinorUnits: pricePaidAmount === null ? null : majorToMinor(pricePaidAmount)
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
