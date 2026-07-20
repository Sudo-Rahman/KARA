import { createHash } from 'node:crypto';

import { describe, expect, test, vi } from 'vitest';

import { MetalsDataCache, type PublicationBytes } from './cache';

const encoder = new TextEncoder();

function jsonBytes(value: unknown): Uint8Array {
	return encoder.encode(`${JSON.stringify(value, null, 2)}\n`);
}

function publication(version: number, month = '1999-01'): PublicationBytes {
	const prices = {
		USD: `${version}.000000`,
		EUR: `${version}.000000`,
		CHF: `${version}.000000`,
		GBP: `${version}.000000`
	};
	const dataBytes = jsonBytes({
		schemaVersion: 1,
		datasetId: 'precious-metals-monthly',
		frequency: 'monthly',
		priceKind: 'monthly_average',
		unit: { code: 'troy_ounce', grams: '31.1034768' },
		methodology: {
			nominal: true,
			currencyConversion: 'ratio_of_monthly_average_rates',
			roundingDecimals: 6,
			roundingMode: 'half_even'
		},
		sources: [
			{
				id: 'imf-pcps',
				role: 'metal_prices_usd',
				title: 'IMF',
				url: 'https://example.test/imf',
				attribution: 'IMF',
				termsUrl: 'https://example.test/imf-terms'
			},
			{
				id: 'eurostat-ert-bil-eur-m',
				role: 'exchange_rates',
				title: 'Eurostat',
				url: 'https://example.test/eurostat',
				attribution: 'Eurostat',
				termsUrl: 'https://example.test/eurostat-terms'
			}
		],
		series: ['XAU', 'XAG', 'XPT', 'XPD'].map((metal) => ({
			metal,
			observations: [{ month, prices }]
		}))
	});
	const sha256 = createHash('sha256').update(dataBytes).digest('hex');
	const manifestBytes = jsonBytes({
		schemaVersion: 1,
		datasetId: 'precious-metals-monthly',
		dataVersion: sha256,
		publishedAt: `2026-07-${String(version).padStart(2, '0')}T05:17:00.000Z`,
		metals: ['XAU', 'XAG', 'XPT', 'XPD'],
		coverage: { from: month, through: month },
		currencies: {
			USD: { from: month, through: month },
			CHF: { from: month, through: month },
			GBP: { from: month, through: month },
			EUR: { from: month, through: month }
		},
		file: {
			url: '/v1/metals-monthly.json',
			sha256,
			bytes: dataBytes.byteLength
		}
	});

	return { manifestBytes, dataBytes };
}

function response(bytes: Uint8Array): Response {
	return new Response(bytes as BodyInit, { status: 200 });
}

function withSnapshotMonth(bytes: PublicationBytes, month: string): PublicationBytes {
	const snapshot = JSON.parse(new TextDecoder().decode(bytes.dataBytes));
	for (const series of snapshot.series) series.observations[0].month = month;
	const dataBytes = jsonBytes(snapshot);
	const sha256 = createHash('sha256').update(dataBytes).digest('hex');
	const manifest = JSON.parse(new TextDecoder().decode(bytes.manifestBytes));
	manifest.dataVersion = sha256;
	manifest.file.sha256 = sha256;
	manifest.file.bytes = dataBytes.byteLength;
	return { manifestBytes: jsonBytes(manifest), dataBytes };
}

describe('MetalsDataCache', () => {
	test('serves its bundled publication immediately when the source is unavailable', async () => {
		const fallback = publication(1);
		const fetcher = vi.fn<typeof fetch>().mockRejectedValue(new Error('offline'));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
		expect(cache.current().data.bytes).toEqual(fallback.dataBytes);
		await expect(cache.refresh()).resolves.toBe('failed');
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
		expect(cache.current().data.bytes).toEqual(fallback.dataBytes);
	});

	test('replaces the complete publication only after validating a changed snapshot', async () => {
		const fallback = publication(1);
		const updated = publication(2);
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(response(updated.manifestBytes))
			.mockResolvedValueOnce(response(updated.dataBytes));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('updated');
		expect(cache.current().manifest.bytes).toEqual(updated.manifestBytes);
		expect(cache.current().data.bytes).toEqual(updated.dataBytes);
		expect(fetcher).toHaveBeenNthCalledWith(
			2,
			'https://example.test/data/v1/metals-monthly.json',
			expect.objectContaining({ cache: 'no-store', signal: expect.any(AbortSignal) })
		);
	});

	test('downloads only the manifest when dataVersion is unchanged', async () => {
		const fallback = publication(1);
		const fetcher = vi.fn<typeof fetch>().mockResolvedValue(response(fallback.manifestBytes));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('unchanged');
		expect(fetcher).toHaveBeenCalledTimes(1);
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
	});

	test('keeps both previous resources when the changed snapshot fails validation', async () => {
		const fallback = publication(1);
		const updated = publication(2);
		const corrupted = updated.dataBytes.slice();
		corrupted[corrupted.length - 2] = 0x20;
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(response(updated.manifestBytes))
			.mockResolvedValueOnce(response(corrupted));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('failed');
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
		expect(cache.current().data.bytes).toEqual(fallback.dataBytes);
	});

	test('rejects a snapshot whose observation coverage disagrees with its manifest', async () => {
		const fallback = publication(1);
		const inconsistent = withSnapshotMonth(publication(2), '1999-02');
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(response(inconsistent.manifestBytes))
			.mockResolvedValueOnce(response(inconsistent.dataBytes));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('failed');
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
		expect(cache.current().data.bytes).toEqual(fallback.dataBytes);
	});

	test('rejects a valid publication whose coverage regresses', async () => {
		const fallback = publication(1, '1999-02');
		const regressive = publication(2, '1999-01');
		const fetcher = vi
			.fn<typeof fetch>()
			.mockResolvedValueOnce(response(regressive.manifestBytes))
			.mockResolvedValueOnce(response(regressive.dataBytes));
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('failed');
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
		expect(cache.current().data.bytes).toEqual(fallback.dataBytes);
	});

	test('stops reading an oversized source without relying on Content-Length', async () => {
		const fallback = publication(1);
		const chunk = new Uint8Array(600 * 1024);
		const source = new ReadableStream<Uint8Array>({
			start(controller) {
				controller.enqueue(chunk);
				controller.enqueue(chunk);
				controller.close();
			}
		});
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher: vi.fn<typeof fetch>().mockResolvedValue(new Response(source)),
			logger: { warn: vi.fn() }
		});

		await expect(cache.refresh()).resolves.toBe('failed');
		expect(cache.current().manifest.bytes).toEqual(fallback.manifestBytes);
	});

	test('coalesces concurrent refreshes into one source request', async () => {
		const fallback = publication(1);
		let release: ((value: Response) => void) | undefined;
		const pending = new Promise<Response>((resolve) => {
			release = resolve;
		});
		const fetcher = vi.fn<typeof fetch>().mockReturnValue(pending);
		const cache = new MetalsDataCache({
			fallback,
			manifestUrl: 'https://example.test/data/v1/manifest.json',
			fetcher,
			logger: { warn: vi.fn() }
		});

		const first = cache.refresh();
		const second = cache.refresh();
		release?.(response(fallback.manifestBytes));

		await expect(Promise.all([first, second])).resolves.toEqual(['unchanged', 'unchanged']);
		expect(fetcher).toHaveBeenCalledTimes(1);
	});
});
