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

export interface SpotQuote {
	schemaVersion: 1;
	metal: Metal;
	currency: Currency;
	price: string;
	unit: {
		code: 'troy_ounce';
		grams: '31.1034768';
	};
	sourceUpdatedAt: string;
}

