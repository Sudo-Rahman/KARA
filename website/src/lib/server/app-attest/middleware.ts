import { createHash } from 'node:crypto';

import { normalizeQuery } from './canonical';
import { AppAttestError } from './errors';
import { appAttestErrorResponse, decodeBase64, normalizeAppAttestError } from './http';
import type { BackendLogger } from '../logger';
import type { AppAttestAuthService } from './service';
import type { AuthenticatedAppAttestRequest, RequestBinding } from './types';

const KEY_ID_HEADER = 'X-Kara-App-Attest-Key-Id';
const CHALLENGE_ID_HEADER = 'X-Kara-App-Attest-Challenge-Id';
const ASSERTION_HEADER = 'X-Kara-App-Attest-Assertion';

export async function authenticateAppAttestRequest(
	request: Request,
	service: AppAttestAuthService | (() => AppAttestAuthService),
	onAuthenticated?: (principal: AuthenticatedAppAttestRequest) => void,
	logger?: Pick<BackendLogger, 'error' | 'warn'>
): Promise<Response | null> {
	const keyId = request.headers.get(KEY_ID_HEADER)?.trim();
	const challengeId = request.headers.get(CHALLENGE_ID_HEADER)?.trim();
	const encodedAssertion = request.headers.get(ASSERTION_HEADER)?.trim();
	if (!keyId || !challengeId || !encodedAssertion) {
		const error = new AppAttestError(
			'app_attest_required',
			401,
			'App Attest headers are required'
		);
		logRejection(logger, error);
		return appAttestErrorResponse(error);
	}

	try {
		const resolvedService = typeof service === 'function' ? service() : service;
		let body: Buffer | undefined;
		await resolvedService.verifyRequest({
			keyId,
			challengeId,
			assertion: decodeBase64(encodedAssertion, ASSERTION_HEADER),
			request: async () => {
				body = await requestBody(request);
				return requestBinding(request, body);
			}
		});
		if (!body) body = Buffer.alloc(0);
		onAuthenticated?.({ keyId, body });
		return null;
	} catch (error) {
		logRejection(logger, error);
		return appAttestErrorResponse(error);
	}
}

function logRejection(
	logger: Pick<BackendLogger, 'error' | 'warn'> | undefined,
	error: unknown
): void {
	if (!logger) return;
	const known = normalizeAppAttestError(error);
	const context = {
		code: known.code,
		event: 'app_attest.authentication_rejected',
		status: known.status
	};
	if (known.status >= 500) {
		logger.error(context, 'App Attest authentication failed');
	} else {
		logger.warn(context, 'App Attest authentication rejected');
	}
}

export async function requestBinding(request: Request, suppliedBody?: Buffer): Promise<RequestBinding> {
	const url = new URL(request.url);
	const body = suppliedBody ?? await requestBody(request);
	return {
		method: request.method.toUpperCase(),
		pathname: url.pathname,
		query: normalizeQuery(url),
		bodySHA256: createHash('sha256').update(body).digest('hex')
	};
}

async function requestBody(request: Request): Promise<Buffer> {
	return request.method === 'GET' || request.method === 'HEAD'
		? Buffer.alloc(0)
		: Buffer.from(await request.arrayBuffer());
}
