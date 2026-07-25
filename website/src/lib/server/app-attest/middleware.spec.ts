import { describe, expect, it } from 'vitest';

import { authenticateAppAttestRequest } from './middleware';

describe('App Attest API middleware', () => {
	it('rejects a protected API request without attestation headers', async () => {
		const response = await authenticateAppAttestRequest(
			new Request('https://kara.test/v1/manifest.json'),
			{} as never
		);

		expect(response?.status).toBe(401);
		expect(await response?.json()).toEqual({
			error: {
				code: 'app_attest_required',
				message: 'App Attest headers are required'
			}
		});
	});
});
