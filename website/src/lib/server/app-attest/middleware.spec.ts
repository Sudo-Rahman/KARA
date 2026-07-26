import { describe, expect, it, vi } from 'vitest';

import { authenticateAppAttestRequest } from './middleware';

describe('App Attest API middleware', () => {
	it('rejects a protected API request without attestation headers', async () => {
		const logger = { error: vi.fn(), warn: vi.fn() };
		const response = await authenticateAppAttestRequest(
			new Request('https://kara.test/v1/manifest.json'),
			{} as never,
			undefined,
			logger
		);

		expect(response?.status).toBe(401);
		expect(await response?.json()).toEqual({
			error: {
				code: 'app_attest_required',
				message: 'App Attest headers are required'
			}
		});
		expect(logger.warn).toHaveBeenCalledWith(
			{
				code: 'app_attest_required',
				event: 'app_attest.authentication_rejected',
				status: 401
			},
			'App Attest authentication rejected'
		);
		expect(logger.error).not.toHaveBeenCalled();
	});

	it('reads a protected binary body once and exposes the verified principal', async () => {
		const request = new Request('https://kara.test/v1/asset-extraction?kind=object-photo&locale=fr-FR', {
			method: 'POST',
			headers: {
				'X-Kara-App-Attest-Key-Id': 'device-key',
				'X-Kara-App-Attest-Challenge-Id': 'challenge',
				'X-Kara-App-Attest-Assertion': Buffer.from('assertion').toString('base64')
			},
			body: 'binary-media'
		});
		let bindingBodyHash: string | undefined;
		const service = {
			verifyRequest: async (input: { request: () => Promise<{ bodySHA256: string }> }) => {
				bindingBodyHash = (await input.request()).bodySHA256;
			}
		};
		let principal: { keyId: string; body: Buffer } | undefined;

		const rejection = await authenticateAppAttestRequest(
			request,
			service as never,
			(value) => { principal = value; }
		);

		expect(rejection).toBeNull();
		expect(request.bodyUsed).toBe(true);
		expect(bindingBodyHash).toMatch(/^[a-f0-9]{64}$/);
		expect(principal).toEqual({ keyId: 'device-key', body: Buffer.from('binary-media') });
	});
});
