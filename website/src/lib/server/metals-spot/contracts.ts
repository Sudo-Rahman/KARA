import { z } from 'zod';

export const METALS = ['XAU', 'XAG', 'XPT', 'XPD'] as const;
export const CURRENCIES = [
	'USD',
	'EUR',
	'GBP',
	'JPY',
	'CAD',
	'AUD',
	'CHF',
	'CNY',
	'HKD',
	'SGD',
	'SEK',
	'NOK',
	'DKK',
	'NZD',
	'MXN',
	'INR',
	'BRL',
	'ZAR',
	'KRW'
] as const;

export const metalSchema = z.enum(METALS);
export const currencySchema = z.enum(CURRENCIES);

export type Metal = z.infer<typeof metalSchema>;
export type Currency = z.infer<typeof currencySchema>;

export const goldApiQuoteSchema = z.object({
	currency: currencySchema,
	currencySymbol: z.string(),
	exchangeRate: z.number().positive().finite(),
	name: z.string().min(1),
	price: z.number().positive().finite(),
	symbol: metalSchema,
	updatedAt: z.iso.datetime({ offset: true }),
	updatedAtReadable: z.string()
});

const spotPriceSchema = z
	.string()
	.regex(/^\d+\.\d{6}$/)
	.refine((value) => Number.isFinite(Number(value)) && Number(value) > 0, 'Price must be positive');

export const spotQuoteSchema = z.object({
	schemaVersion: z.literal(1),
	metal: metalSchema,
	currency: currencySchema,
	price: spotPriceSchema,
	unit: z.object({
		code: z.literal('troy_ounce'),
		grams: z.literal('31.1034768')
	}),
	sourceUpdatedAt: z.iso.datetime({ offset: true })
});

export type SpotQuote = z.infer<typeof spotQuoteSchema>;
