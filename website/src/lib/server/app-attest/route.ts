import { AppAttestError } from './errors';
import { appAttestErrorResponse } from './http';

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

export function appAttestRouteError(error: unknown): Response {
	return appAttestErrorResponse(error);
}
