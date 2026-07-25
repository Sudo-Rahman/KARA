import { AppAttestError } from './errors';

export function appAttestErrorResponse(error: unknown): Response {
	const known = error instanceof AppAttestError
		? error
		: new AppAttestError(
			'app_attest_store_unavailable',
			503,
			'App attestation is temporarily unavailable',
			{ cause: error }
		);
	return Response.json(
		{ error: { code: known.code, message: known.message } },
		{
			status: known.status,
			headers: {
				'Cache-Control': 'no-store',
				'X-Content-Type-Options': 'nosniff'
			}
		}
	);
}

export function decodeBase64(value: string, label: string, maximumBytes = 32_768): Buffer {
	const normalized = value.trim();
	if (!/^[A-Za-z0-9+/_-]+={0,2}$/.test(normalized)) {
		throw new AppAttestError('invalid_app_attest_assertion', 401, `${label} is not valid base64`);
	}
	const isURLSafe = normalized.includes('-') || normalized.includes('_');
	const encoding = isURLSafe ? 'base64url' : 'base64';
	const decoded = Buffer.from(normalized, encoding);
	const unpaddedInput = normalized.replace(/=+$/, '');
	const canonical = decoded.toString(encoding).replace(/=+$/, '');
	if (decoded.length === 0 || canonical !== unpaddedInput || decoded.length > maximumBytes) {
		throw new AppAttestError('invalid_app_attest_assertion', 401, `${label} is invalid or too large`);
	}
	return decoded;
}
