import { createHash } from 'node:crypto';

import { normalizeQuery } from './canonical';
import { AppAttestError } from './errors';
import { appAttestErrorResponse, decodeBase64 } from './http';
import type { AppAttestAuthService } from './service';
import type { RequestBinding } from './types';

const KEY_ID_HEADER = 'X-Kara-App-Attest-Key-Id';
const CHALLENGE_ID_HEADER = 'X-Kara-App-Attest-Challenge-Id';
const ASSERTION_HEADER = 'X-Kara-App-Attest-Assertion';

export async function authenticateAppAttestRequest(
	request: Request,
	service: AppAttestAuthService | (() => AppAttestAuthService)
): Promise<Response | null> {
	const keyId = request.headers.get(KEY_ID_HEADER)?.trim();
	const challengeId = request.headers.get(CHALLENGE_ID_HEADER)?.trim();
	const encodedAssertion = request.headers.get(ASSERTION_HEADER)?.trim();
	if (!keyId || !challengeId || !encodedAssertion) {
		return appAttestErrorResponse(new AppAttestError(
			'app_attest_required',
			401,
			'App Attest headers are required'
		));
	}

	try {
		const resolvedService = typeof service === 'function' ? service() : service;
		await resolvedService.verifyRequest({
			keyId,
			challengeId,
			assertion: decodeBase64(encodedAssertion, ASSERTION_HEADER),
			request: () => requestBinding(request)
		});
		return null;
	} catch (error) {
		return appAttestErrorResponse(error);
	}
}

export async function requestBinding(request: Request): Promise<RequestBinding> {
	const url = new URL(request.url);
	const body = request.method === 'GET' || request.method === 'HEAD'
		? Buffer.alloc(0)
		: Buffer.from(await request.clone().arrayBuffer());
	return {
		method: request.method.toUpperCase(),
		pathname: url.pathname,
		query: normalizeQuery(url),
		bodySHA256: createHash('sha256').update(body).digest('hex')
	};
}
