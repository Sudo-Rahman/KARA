export type AnalysisErrorCode =
	| 'INVALID_ANALYSIS_INPUT'
	| 'UNSUPPORTED_MEDIA_TYPE'
	| 'ANALYSIS_PAYLOAD_TOO_LARGE'
	| 'ANALYSIS_RATE_LIMITED'
	| 'ANALYSIS_DAILY_LIMIT_REACHED'
	| 'ANALYSIS_QUARANTINED'
	| 'ANALYSIS_REFUSED'
	| 'INVALID_UPSTREAM_RESPONSE'
	| 'ANALYSIS_UNAVAILABLE'
	| 'ANALYSIS_TIMEOUT';

export class AnalysisError extends Error {
	constructor(
		readonly code: AnalysisErrorCode,
		readonly status: number,
		message: string,
		readonly retryAfterSeconds?: number,
		options?: ErrorOptions
	) {
		super(message, options);
		this.name = 'AnalysisError';
	}
}

