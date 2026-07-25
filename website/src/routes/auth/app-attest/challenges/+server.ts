import type { RequestHandler } from './$types';

import { challengeRequestSchema } from '$lib/server/app-attest/contracts';
import { appAttestRouteError, parseJSON } from '$lib/server/app-attest/route';
import { appAttestService } from '$lib/server/app-attest/runtime';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const input = await parseJSON(request, challengeRequestSchema.parse);
		const challenge = input.purpose === 'registration'
			? await appAttestService().createRegistrationChallenge(input.keyId)
			: await appAttestService().createAssertionChallenge(input.keyId, input.request);
		return Response.json(challenge, {
			status: 201,
			headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }
		});
	} catch (error) {
		return appAttestRouteError(error);
	}
};
