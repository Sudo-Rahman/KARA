import { AppAttestError } from './errors';
import { appAttestErrorResponse, normalizeAppAttestError } from './http';
import type { BackendLogger } from '../logger';

export async function parseJSON<T>(request: Request, parser: (value: unknown) => T): Promise<T> {
	try {
		return parser(await request.json());
	} catch (error) {
		throw new AppAttestError(
			'invalid_app_attest_assertion',
			400,
			'App Attest request body is invalid',
			{ cause: error }
		);
	}
}

export function appAttestRouteError(
	error: unknown,
	logger?: Pick<BackendLogger, 'error' | 'warn'>
): Response {
	if (logger) {
		const known = normalizeAppAttestError(error);
		const context = {
			code: known.code,
			event: 'app_attest.operation_failed',
			status: known.status
		};
		if (known.status >= 500) {
			logger.error(context, 'App Attest operation failed');
		} else {
			logger.warn(context, 'App Attest operation rejected');
		}
	}
	return appAttestErrorResponse(error);
}
