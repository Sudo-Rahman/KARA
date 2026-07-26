import { describe, expect, test, vi } from 'vitest';

import { modelSuggestionSchema } from './contracts';
import { AssetExtractionService } from './service';
import type { AnalysisQuotaStore } from './redis-quota';

function jpeg(): Buffer {
	return Buffer.from([
		0xff, 0xd8, 0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01,
		0x01, 0x01, 0x11, 0x00, 0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00,
		0x3f, 0x00, 0x00, 0xff, 0xd9
	]);
}

const emptySuggestion = modelSuggestionSchema.parse({
	name: null, category: null, presetId: null, quantity: null, purchaseDate: null,
	metal: null, weightGrams: null, metalKarat: null, finenessPermille: null,
	gemstoneCaratWeight: null, gemstoneClarity: null, pricePaidAmount: null,
	currencyCode: null, sellerName: null, storageLocationName: null,
	invoiceNumber: null, serialNumber: null
});

function dependencies(overrides: Partial<{
	recordAttempt: AnalysisQuotaStore['recordAttempt'];
	reserve: AnalysisQuotaStore['reserve'];
}> = {}) {
	const quota: AnalysisQuotaStore = {
		ping: vi.fn(),
		recordAttempt: overrides.recordAttempt ?? vi.fn().mockResolvedValue({ kind: 'accepted' }),
		reserve: overrides.reserve ?? vi.fn().mockImplementation(async ({ requestId }) => ({
			kind: 'accepted', lockToken: requestId
		})),
		release: vi.fn()
	};
	const extractor = {
		extract: vi.fn().mockResolvedValue({
			suggestion: { ...emptySuggestion, serialNumber: 'A-001' },
			usage: { inputTokens: 100, outputTokens: 20, totalTokens: 120 }
		})
	};
	const logger = { info: vi.fn() };
	const service = new AssetExtractionService({
		hmacSecret: Buffer.alloc(32, 5), quota, extractor, logger,
		now: () => new Date('2026-07-25T12:00:00.000Z'),
		requestId: () => '00000000-0000-4000-8000-000000000001'
	});
	return { service, quota, extractor, logger };
}

describe('asset extraction service', () => {
	test('returns the versioned JSON contract after an authenticated, reserved analysis', async () => {
		const bytes = jpeg();
		const { service, quota, extractor, logger } = dependencies();
		const response = await service.handle({
			request: new Request(
				'https://kara.example/v1/asset-extraction?kind=object-photo&locale=fr-FR',
				{ method: 'POST', headers: { 'Content-Type': 'image/jpeg', 'Content-Length': String(bytes.length) } }
			),
			principal: { keyId: 'raw-app-attest-key', body: bytes },
			clientAddress: '203.0.113.10'
		});

		expect(response.status).toBe(200);
		expect(response.headers.get('cache-control')).toBe('no-store');
		expect(response.headers.get('x-content-type-options')).toBe('nosniff');
		expect(response.headers.get('x-request-id')).toBe('00000000-0000-4000-8000-000000000001');
		expect(await response.json()).toMatchObject({
			schemaVersion: 1,
			suggestion: { serialNumber: 'A-001', pricePaidMinorUnits: null }
		});
		expect(quota.recordAttempt).toHaveBeenCalledWith(expect.objectContaining({
			installationId: expect.stringMatching(/^[a-f0-9]{64}$/),
			ipId: expect.stringMatching(/^[a-f0-9]{64}$/)
		}));
		expect(quota.reserve).toHaveBeenCalledWith(expect.objectContaining({
			installationId: expect.stringMatching(/^[a-f0-9]{64}$/),
			ipId: expect.stringMatching(/^[a-f0-9]{64}$/)
		}));
		expect(extractor.extract).toHaveBeenCalledWith(expect.objectContaining({
			kind: 'object-photo', locale: 'fr-FR',
			safetyIdentifier: expect.stringMatching(/^[a-f0-9]{64}$/),
			signal: expect.any(AbortSignal)
		}));
		expect(quota.release).toHaveBeenCalledWith(
			expect.stringMatching(/^[a-f0-9]{64}$/),
			expect.stringMatching(/^[a-f0-9]{64}$/),
			'00000000-0000-4000-8000-000000000001'
		);
		const quotaIdentity = vi.mocked(quota.recordAttempt).mock.calls[0][0];
		expect(JSON.stringify(vi.mocked(quota.recordAttempt).mock.calls)).not.toContain('raw-app-attest-key');
		expect(JSON.stringify(logger.info.mock.calls)).not.toContain(quotaIdentity.installationId);
		expect(JSON.stringify(logger.info.mock.calls)).not.toContain(quotaIdentity.ipId);
		expect(JSON.stringify(logger.info.mock.calls)).not.toContain('raw-app-attest-key');
		expect(JSON.stringify(logger.info.mock.calls)).not.toContain('A-001');
	});

	test('counts authenticated invalid input but never reserves or calls OpenAI', async () => {
		const { service, quota, extractor } = dependencies();
		const response = await service.handle({
			request: new Request(
				'https://kara.example/v1/asset-extraction?kind=object-photo&locale=fr-FR',
				{ method: 'POST', headers: { 'Content-Type': 'image/png', 'Content-Length': '4' } }
			),
			principal: { keyId: 'raw-key', body: Buffer.from('nope') },
			clientAddress: '203.0.113.10'
		});

		expect(response.status).toBe(415);
		expect(await response.json()).toMatchObject({ error: { code: 'UNSUPPORTED_MEDIA_TYPE' } });
		expect(quota.recordAttempt).toHaveBeenCalledOnce();
		expect(quota.reserve).not.toHaveBeenCalled();
		expect(extractor.extract).not.toHaveBeenCalled();
	});

	test('returns stable quota codes and Retry-After without inspecting media', async () => {
		const { service, extractor } = dependencies({
			recordAttempt: vi.fn().mockResolvedValue({ kind: 'quarantined', retryAfterSeconds: 604_800 })
		});
		const response = await service.handle({
			request: new Request('https://kara.example/v1/asset-extraction?kind=invoice&locale=fr-FR', {
				method: 'POST', headers: { 'Content-Type': 'application/pdf', 'Content-Length': '1' }
			}),
			principal: { keyId: 'raw-key', body: Buffer.from('x') },
			clientAddress: '203.0.113.10'
		});

		expect(response.status).toBe(403);
		expect(response.headers.get('retry-after')).toBe('604800');
		expect(await response.json()).toMatchObject({ error: { code: 'ANALYSIS_QUARANTINED' } });
		expect(extractor.extract).not.toHaveBeenCalled();
	});

	test.each([
		['ip_daily_limited', 'ANALYSIS_DAILY_LIMIT_REACHED'],
		['ip_concurrent', 'ANALYSIS_RATE_LIMITED']
	] as const)('maps %s to the stable public quota contract', async (kind, expectedCode) => {
		const bytes = jpeg();
		const { service, extractor } = dependencies({
			reserve: vi.fn().mockResolvedValue({ kind, retryAfterSeconds: 60 })
		});
		const response = await service.handle({
			request: new Request(
				'https://kara.example/v1/asset-extraction?kind=object-photo&locale=fr-FR',
				{ method: 'POST', headers: { 'Content-Type': 'image/jpeg', 'Content-Length': String(bytes.length) } }
			),
			principal: { keyId: 'raw-key', body: bytes },
			clientAddress: '203.0.113.10'
		});

		expect(response.status).toBe(429);
		expect(response.headers.get('retry-after')).toBe('60');
		expect(await response.json()).toMatchObject({ error: { code: expectedCode } });
		expect(extractor.extract).not.toHaveBeenCalled();
	});

	test('propagates client cancellation and releases installation and IP locks', async () => {
		const controller = new AbortController();
		const { service, quota, extractor } = dependencies();
		vi.mocked(extractor.extract).mockImplementation(async ({ signal }) => {
			await new Promise<void>((_resolve, reject) => {
				signal.addEventListener('abort', () => reject(
					Object.assign(new Error('cancelled'), { name: 'AbortError' })
				), { once: true });
			});
			throw new Error('unreachable');
		});
		const bytes = jpeg();
		const responsePromise = service.handle({
			request: new Request(
				'https://kara.example/v1/asset-extraction?kind=object-photo&locale=fr-FR',
				{
					method: 'POST',
					headers: { 'Content-Type': 'image/jpeg', 'Content-Length': String(bytes.length) },
					signal: controller.signal
				}
			),
			principal: { keyId: 'raw-key', body: bytes },
			clientAddress: '203.0.113.10'
		});
		await vi.waitFor(() => expect(extractor.extract).toHaveBeenCalledOnce());
		controller.abort();
		const response = await responsePromise;

		expect(response.status).toBe(503);
		expect(quota.release).toHaveBeenCalledWith(
			expect.stringMatching(/^[a-f0-9]{64}$/),
			expect.stringMatching(/^[a-f0-9]{64}$/),
			'00000000-0000-4000-8000-000000000001'
		);
	});
});
