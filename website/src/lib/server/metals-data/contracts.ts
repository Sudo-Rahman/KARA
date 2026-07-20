import { createHash } from 'node:crypto';

import { z } from 'zod';

const month = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/);
const coverage = z.object({ from: month, through: month });
const sha256 = z.string().regex(/^[0-9a-f]{64}$/);
const price = z
	.string()
	.regex(/^\d+\.\d{6}$/)
	.refine((value) => Number.isFinite(Number(value)) && Number(value) > 0, 'Price must be positive');

const prices = z
	.object({
		USD: price,
		CHF: price,
		GBP: price,
		XEU: price.optional(),
		EUR: price.optional()
	})
	.refine((value) => (value.XEU === undefined) !== (value.EUR === undefined), {
		message: 'Prices must contain exactly one of XEU or EUR'
	});

const observation = z.object({ month, prices });
const metal = z.enum(['XAU', 'XAG', 'XPT', 'XPD']);

export const manifestSchema = z
	.object({
		schemaVersion: z.literal(1),
		datasetId: z.literal('precious-metals-monthly'),
		dataVersion: sha256,
		publishedAt: z.iso.datetime({ offset: false }),
		metals: z.tuple([
			z.literal('XAU'),
			z.literal('XAG'),
			z.literal('XPT'),
			z.literal('XPD')
		]),
		coverage,
		currencies: z.object({
			USD: coverage,
			CHF: coverage,
			GBP: coverage,
			XEU: coverage.optional(),
			EUR: coverage.optional()
		}),
		file: z.object({
			url: z.literal('/v1/metals-monthly.json'),
			sha256,
			bytes: z.number().int().positive()
		})
	})
	.superRefine((value, context) => {
		if (value.dataVersion !== value.file.sha256) {
			context.addIssue({
				code: 'custom',
				message: 'Manifest hashes must match',
				path: ['file', 'sha256']
			});
		}
		if (value.coverage.from > value.coverage.through) {
			context.addIssue({ code: 'custom', message: 'Invalid coverage range', path: ['coverage'] });
		}
		for (const currency of ['USD', 'CHF', 'GBP'] as const) {
			if (
				value.currencies[currency].from !== value.coverage.from ||
				value.currencies[currency].through !== value.coverage.through
			) {
				context.addIssue({
					code: 'custom',
					message: `${currency} coverage must match dataset coverage`,
					path: ['currencies', currency]
				});
			}
		}
		const expectedXeuThrough = value.coverage.through < '1999-01' ? value.coverage.through : '1998-12';
		if (
			value.coverage.from < '1999-01'
				? value.currencies.XEU?.from !== value.coverage.from ||
					value.currencies.XEU?.through !== expectedXeuThrough
				: value.currencies.XEU !== undefined
		) {
			context.addIssue({
				code: 'custom',
				message: 'XEU coverage is inconsistent with dataset coverage',
				path: ['currencies', 'XEU']
			});
		}
		const expectedEurFrom = value.coverage.from >= '1999-01' ? value.coverage.from : '1999-01';
		if (
			value.coverage.through >= '1999-01'
				? value.currencies.EUR?.from !== expectedEurFrom ||
					value.currencies.EUR?.through !== value.coverage.through
				: value.currencies.EUR !== undefined
		) {
			context.addIssue({
				code: 'custom',
				message: 'EUR coverage is inconsistent with dataset coverage',
				path: ['currencies', 'EUR']
			});
		}
	});

function monthIndex(value: string): number {
	const [year, number] = value.split('-').map(Number);
	return year! * 12 + number! - 1;
}

export const snapshotSchema = z
	.object({
		schemaVersion: z.literal(1),
		datasetId: z.literal('precious-metals-monthly'),
		frequency: z.literal('monthly'),
		priceKind: z.literal('monthly_average'),
		unit: z.object({
			code: z.literal('troy_ounce'),
			grams: z.literal('31.1034768')
		}),
		methodology: z.object({
			nominal: z.literal(true),
			currencyConversion: z.literal('ratio_of_monthly_average_rates'),
			roundingDecimals: z.literal(6),
			roundingMode: z.literal('half_even')
		}),
		sources: z
			.array(
				z.object({
					id: z.string().min(1),
					role: z.enum(['metal_prices_usd', 'exchange_rates']),
					title: z.string().min(1),
					url: z.url(),
					attribution: z.string().min(1),
					termsUrl: z.url()
				})
			)
			.min(2),
		series: z
			.array(
				z.object({
					metal,
					observations: z.array(observation).min(1)
				})
			)
			.length(4)
	})
	.superRefine((snapshot, context) => {
		const expectedMetals = ['XAU', 'XAG', 'XPT', 'XPD'] as const;
		const expectedMonths = snapshot.series[0]?.observations.map((item) => item.month) ?? [];

		snapshot.series.forEach((series, seriesIndex) => {
			if (series.metal !== expectedMetals[seriesIndex]) {
				context.addIssue({
					code: 'custom',
					message: `Expected ${expectedMetals[seriesIndex]}`,
					path: ['series', seriesIndex, 'metal']
				});
			}

			if (series.observations.length !== expectedMonths.length) {
				context.addIssue({
					code: 'custom',
					message: 'All series must contain the same months',
					path: ['series', seriesIndex, 'observations']
				});
			}

			series.observations.forEach((item, observationIndex) => {
				if (item.month !== expectedMonths[observationIndex]) {
					context.addIssue({
						code: 'custom',
						message: 'All series must contain the same months',
						path: ['series', seriesIndex, 'observations', observationIndex, 'month']
					});
				}
				if (item.month < '1999-01' ? item.prices.XEU === undefined : item.prices.EUR === undefined) {
					context.addIssue({
						code: 'custom',
						message: 'Observation currency does not match its month',
						path: ['series', seriesIndex, 'observations', observationIndex, 'prices']
					});
				}
				if (
					observationIndex > 0 &&
					monthIndex(item.month) !== monthIndex(series.observations[observationIndex - 1]!.month) + 1
				) {
					context.addIssue({
						code: 'custom',
						message: 'Observation months must be continuous',
						path: ['series', seriesIndex, 'observations', observationIndex, 'month']
					});
				}
			});
		});
	});

export type MetalsManifest = z.infer<typeof manifestSchema>;

const decoder = new TextDecoder('utf-8', { fatal: true });

function parseJson(bytes: Uint8Array, label: string): unknown {
	try {
		return JSON.parse(decoder.decode(bytes));
	} catch (error) {
		throw new Error(`Invalid ${label} JSON`, { cause: error });
	}
}

export function hashBytes(bytes: Uint8Array): string {
	return createHash('sha256').update(bytes).digest('hex');
}

export function parseManifest(bytes: Uint8Array): MetalsManifest {
	return manifestSchema.parse(parseJson(bytes, 'manifest'));
}

export function verifyPublication(manifestBytes: Uint8Array, dataBytes: Uint8Array): MetalsManifest {
	const manifest = parseManifest(manifestBytes);
	if (manifest.file.bytes !== dataBytes.byteLength) {
		throw new Error('Snapshot byte length does not match the manifest');
	}
	if (hashBytes(dataBytes) !== manifest.file.sha256) {
		throw new Error('Snapshot SHA-256 does not match the manifest');
	}
	const snapshot = snapshotSchema.parse(parseJson(dataBytes, 'snapshot'));
	const observations = snapshot.series[0]!.observations;
	if (
		observations[0]!.month !== manifest.coverage.from ||
		observations.at(-1)!.month !== manifest.coverage.through
	) {
		throw new Error('Snapshot coverage does not match the manifest');
	}
	return manifest;
}
