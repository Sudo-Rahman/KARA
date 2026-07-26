import { describe, expect, test, vi } from 'vitest';
import { APIConnectionTimeoutError, APIUserAbortError } from 'openai';

import { OpenAIAssetExtractor, SYSTEM_PROMPT, type ResponsesBoundary } from './openai';

const emptySuggestion = {
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
	acquisitionMethod: null
};

const visibleCandidate = <Value>(value: Value, confidencePercent = 95) => ({
	value,
	confidencePercent,
	evidenceKind: 'visible_text' as const
});

describe('OpenAI asset extractor', () => {
	test('keeps tags outside the extraction schema and prompt', () => {
		expect(SYSTEM_PROMPT).toContain('Tags are strictly manual');
		expect(SYSTEM_PROMPT).toContain('never generate, infer, or return tags');
	});

	test('sends one high-detail inline JPEG to GPT-5.6 Luna using strict Responses output', async () => {
		const parse = vi.fn().mockResolvedValue({
			output_parsed: { ...emptySuggestion, serialNumber: visibleCandidate('A-001') },
			output: [],
			usage: { input_tokens: 321, output_tokens: 42, total_tokens: 363 }
		});
		const extractor = new OpenAIAssetExtractor({ parse } as ResponsesBoundary);

		const result = await extractor.extract({
			kind: 'object-photo',
			bytes: Buffer.from('jpeg'),
			contentType: 'image/jpeg',
			width: 10,
			height: 10,
			locale: 'fr-FR',
			safetyIdentifier: 'a'.repeat(64),
			signal: new AbortController().signal
		});

		expect(result.suggestion.serialNumber?.value).toBe('A-001');
		expect(result.usage).toEqual({ inputTokens: 321, outputTokens: 42, totalTokens: 363 });
		expect(parse).toHaveBeenCalledOnce();
		const [request, options] = parse.mock.calls[0];
		expect(request).toMatchObject({
			model: 'gpt-5.6-luna',
			reasoning: { effort: 'none' },
			store: false,
			max_output_tokens: 2400,
			safety_identifier: 'a'.repeat(64),
			text: { format: { type: 'json_schema', name: 'asset_extraction', strict: true } },
			input: [
				{ role: 'system', content: SYSTEM_PROMPT },
				{
					role: 'user',
					content: expect.arrayContaining([{
						type: 'input_image',
						image_url: `data:image/jpeg;base64,${Buffer.from('jpeg').toString('base64')}`,
						detail: 'high'
					}])
				}
			]
		});
		expect(request).not.toHaveProperty('tools');
		expect(options.signal).toBeInstanceOf(AbortSignal);
		expect(SYSTEM_PROMPT).toContain('confidencePercent');
		expect(SYSTEM_PROMPT).toContain('deterministic unit normalization');
		expect(SYSTEM_PROMPT).toContain('return a candidate even when confidence is low');
	});

	test('sends invoices inline with explicit high PDF detail and a fixed filename', async () => {
		const parse = vi.fn().mockResolvedValue({ output_parsed: emptySuggestion, output: [] });
		const extractor = new OpenAIAssetExtractor({ parse } as ResponsesBoundary);

		await extractor.extract({
			kind: 'invoice',
			bytes: Buffer.from('%PDF-test'),
			contentType: 'application/pdf',
			pageCount: 2,
			locale: 'en-US',
			safetyIdentifier: 'b'.repeat(64),
			signal: new AbortController().signal
		});

		expect(parse.mock.calls[0][0].input[1].content).toContainEqual({
			type: 'input_file',
			filename: 'invoice.pdf',
			file_data: `data:application/pdf;base64,${Buffer.from('%PDF-test').toString('base64')}`,
			detail: 'high'
		});
	});

	test('maps refusals and malformed structured output without retrying', async () => {
		const refusal = vi.fn().mockResolvedValue({
			output_parsed: null,
			output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'not allowed' }] }]
		});
		await expect(new OpenAIAssetExtractor({ parse: refusal } as ResponsesBoundary).extract({
			kind: 'object-photo', bytes: Buffer.from('x'), contentType: 'image/jpeg', width: 1, height: 1,
			locale: 'fr-FR', safetyIdentifier: 'c'.repeat(64), signal: new AbortController().signal
		})).rejects.toMatchObject({ code: 'ANALYSIS_REFUSED', status: 422 });
		expect(refusal).toHaveBeenCalledOnce();

		const invalid = vi.fn().mockResolvedValue({
			output_parsed: { ...emptySuggestion, hidden: true }, output: []
		});
		await expect(new OpenAIAssetExtractor({ parse: invalid } as ResponsesBoundary).extract({
			kind: 'object-photo', bytes: Buffer.from('x'), contentType: 'image/jpeg', width: 1, height: 1,
			locale: 'fr-FR', safetyIdentifier: 'd'.repeat(64), signal: new AbortController().signal
		})).rejects.toMatchObject({ code: 'INVALID_UPSTREAM_RESPONSE', status: 502 });
		expect(invalid).toHaveBeenCalledOnce();
	});

	test('maps upstream throttling and timeouts to stable non-sensitive errors', async () => {
		const input = {
			kind: 'object-photo' as const,
			bytes: Buffer.from('x'),
			contentType: 'image/jpeg' as const,
			width: 1,
			height: 1,
			locale: 'fr-FR',
			safetyIdentifier: 'e'.repeat(64),
			signal: new AbortController().signal
		};
		const throttled = vi.fn().mockRejectedValue(Object.assign(new Error('secret upstream body'), {
			status: 429
		}));
		await expect(
			new OpenAIAssetExtractor({ parse: throttled } as ResponsesBoundary).extract(input)
		).rejects.toMatchObject({ code: 'ANALYSIS_UNAVAILABLE', status: 503 });
		expect(throttled).toHaveBeenCalledOnce();

		const timedOut = vi.fn().mockRejectedValue(new APIConnectionTimeoutError());
		await expect(
			new OpenAIAssetExtractor({ parse: timedOut } as ResponsesBoundary).extract(input)
		).rejects.toMatchObject({ code: 'ANALYSIS_TIMEOUT', status: 504 });
		expect(timedOut).toHaveBeenCalledOnce();
	});

	test('passes client cancellation to the SDK without misclassifying it as a timeout', async () => {
		const controller = new AbortController();
		let upstreamSignal: AbortSignal | undefined;
		const parse = vi.fn().mockImplementation(async (
			_request: unknown,
			options: { signal: AbortSignal }
		) => {
			upstreamSignal = options.signal;
			await new Promise<void>((_resolve, reject) => {
				options.signal.addEventListener('abort', () => reject(new APIUserAbortError()), { once: true });
			});
			throw new Error('unreachable');
		});
		const promise = new OpenAIAssetExtractor({ parse } as ResponsesBoundary).extract({
			kind: 'object-photo',
			bytes: Buffer.from('x'),
			contentType: 'image/jpeg',
			width: 1,
			height: 1,
			locale: 'fr-FR',
			safetyIdentifier: 'f'.repeat(64),
			signal: controller.signal
		});
		await vi.waitFor(() => expect(parse).toHaveBeenCalledOnce());
		controller.abort();

		await expect(promise).rejects.toMatchObject({ code: 'ANALYSIS_UNAVAILABLE', status: 503 });
		expect(upstreamSignal?.aborted).toBe(true);
	});
});
