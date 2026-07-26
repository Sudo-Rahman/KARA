import { describe, expect, it, vi } from 'vitest';

import { authenticateAppAttestRequest } from './middleware';

describe('App Attest API middleware', () => {
	it('rejects a protected API request without attestation headers', async () => {
		const logger = { error: vi.fn(), warn: vi.fn() };
		const result = await authenticateAppAttestRequest(
			new Request('https://kara.test/v1/manifest.json'),
			{} as never,
			logger
		);

		expect(result.authenticated).toBe(false);
		if (result.authenticated) throw new Error('Expected rejection');
		expect(result.response.status).toBe(401);
		expect(await result.response.json()).toEqual({
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
		const result = await authenticateAppAttestRequest(request, service as never);

		expect(result.authenticated).toBe(true);
		if (!result.authenticated) throw new Error('Expected authenticated principal');
		expect(request.bodyUsed).toBe(false);
		expect(bindingBodyHash).toMatch(/^[a-f0-9]{64}$/);
		expect(result.principal).toEqual({ keyId: 'device-key', body: Buffer.from('binary-media') });
		expect(await request.text()).toBe('binary-media');
	});
});
