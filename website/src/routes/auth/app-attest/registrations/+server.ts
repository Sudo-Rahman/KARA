import type { RequestHandler } from './$types';

import { registrationRequestSchema } from '$lib/server/app-attest/contracts';
import { AppAttestError } from '$lib/server/app-attest/errors';
import { decodeBase64 } from '$lib/server/app-attest/http';
import { appAttestRouteError, parseJSON } from '$lib/server/app-attest/route';
import { appAttestService } from '$lib/server/app-attest/runtime';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const input = await parseJSON(request, registrationRequestSchema.parse);
		let attestation: Buffer;
		try {
			attestation = decodeBase64(input.attestation, 'attestation', 98_304);
		} catch (error) {
			throw new AppAttestError(
				'invalid_app_attest_registration',
				400,
				'Attestation object is not valid base64',
				{ cause: error }
			);
		}
		await appAttestService().register({
			challengeId: input.challengeId,
			keyId: input.keyId,
			attestation
		});
		return Response.json(
			{ registered: true },
			{ status: 201, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } }
		);
	} catch (error) {
		return appAttestRouteError(error);
	}
};
