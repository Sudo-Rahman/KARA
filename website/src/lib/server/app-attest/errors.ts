export type AppAttestErrorCode =
	| 'app_attest_required'
	| 'unknown_app_attest_key'
	| 'invalid_app_attest_assertion'
	| 'invalid_app_attest_registration'
	| 'expired_app_attest_challenge'
	| 'replayed_app_attest_assertion'
	| 'app_attest_store_unavailable';

export class AppAttestError extends Error {
	constructor(
		readonly code: AppAttestErrorCode,
		readonly status: number,
		message: string,
		options?: ErrorOptions
	) {
		super(message, options);
		this.name = 'AppAttestError';
	}
}

export function storeUnavailable(cause: unknown): AppAttestError {
	return new AppAttestError(
		'app_attest_store_unavailable',
		503,
		'App attestation storage is temporarily unavailable',
		{ cause }
	);
}
