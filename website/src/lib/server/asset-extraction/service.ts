import { randomUUID } from 'node:crypto';

import { toPublicExtraction } from './contracts';
import { AnalysisError } from './errors';
import { pseudonymize } from './identity';
import { validateAnalysisMedia, type AnalysisKind } from './media';
import type { ExtractionResult, OpenAIAssetExtractor } from './openai';
import type { AnalysisQuotaStore, AttemptDecision, ReservationDecision } from './redis-quota';
import type { BackendLogger } from '../logger';
import { errorSummary, logger as rootLogger } from '../logger';

export interface AppAttestPrincipal {
	keyId: string;
	body: Uint8Array;
}

interface SafeAnalysisLog {
	timestamp: string;
	requestId: string;
	kind?: AnalysisKind;
	sizeBytes: number;
	pageCount?: number;
	latencyMilliseconds: number;
	status: number;
	code: 'OK' | AnalysisError['code'];
	inputTokens: number | null;
	outputTokens: number | null;
	totalTokens: number | null;
}

type AssetExtractionLogger = Pick<BackendLogger, 'error' | 'info' | 'warn'>;

interface AssetExtractionServiceOptions {
	hmacSecret: Buffer;
	quota: AnalysisQuotaStore;
	extractor: Pick<OpenAIAssetExtractor, 'extract'>;
	logger?: AssetExtractionLogger;
	now?: () => Date;
	requestId?: () => string;
}

export class AssetExtractionService {
	readonly #hmacSecret: Buffer;
	readonly #quota: AnalysisQuotaStore;
	readonly #extractor: Pick<OpenAIAssetExtractor, 'extract'>;
	readonly #logger: AssetExtractionLogger;
	readonly #now: () => Date;
	readonly #requestId: () => string;

	constructor(options: AssetExtractionServiceOptions) {
		this.#hmacSecret = options.hmacSecret;
		this.#quota = options.quota;
		this.#extractor = options.extractor;
		this.#logger = options.logger ?? rootLogger.child({ component: 'asset-extraction' });
		this.#now = options.now ?? (() => new Date());
		this.#requestId = options.requestId ?? randomUUID;
	}

	async ready(): Promise<void> {
		await this.#quota.ping();
	}

	async handle(input: {
		request: Request;
		principal: AppAttestPrincipal;
		clientAddress: string;
		requestId?: string;
	}): Promise<Response> {
		const startedAt = this.#now();
		const requestId = input.requestId ?? this.#requestId();
		const installationId = pseudonymize(this.#hmacSecret, 'installation', input.principal.keyId);
		const ipId = pseudonymize(this.#hmacSecret, 'ip', input.clientAddress);
		const bytes = Buffer.isBuffer(input.principal.body)
			? input.principal.body
			: Buffer.from(input.principal.body);
		let kind: AnalysisKind | undefined;
		let pageCount: number | undefined;
		let usage: ExtractionResult['usage'] = {
			inputTokens: null, outputTokens: null, totalTokens: null
		};
	let status = 500;
	let code: 'OK' | AnalysisError['code'] = 'ANALYSIS_UNAVAILABLE';
	let failure: Record<string, unknown> | undefined;

		try {
			const nowMilliseconds = startedAt.getTime();
			const attempt = await this.#quota.recordAttempt({
				installationId,
				ipId,
				requestId,
				nowMilliseconds
			}).catch((error: unknown) => {
				throw unavailable(error);
			});
			throwForAttemptDecision(attempt);

			const query = parseQuery(input.request);
			kind = query.kind;
			const media = await validateAnalysisMedia({
				kind,
				contentType: normalizedContentType(input.request.headers.get('content-type')),
				contentLength: parseContentLength(input.request.headers.get('content-length')),
				bytes
			});
			if (media.kind === 'invoice') pageCount = media.pageCount;

			const reservation = await this.#quota.reserve({
				installationId,
				ipId,
				requestId,
				nowMilliseconds
			}).catch((error: unknown) => {
				throw unavailable(error);
			});
			throwForReservationDecision(reservation);
			if (reservation.kind !== 'accepted') throw new Error('Unreachable quota state');

			let result: ExtractionResult;
			try {
				result = await this.#extractor.extract({
					...media,
					locale: query.locale,
					safetyIdentifier: installationId,
					signal: input.request.signal
				});
				usage = result.usage;
			} finally {
				try {
					await this.#quota.release(installationId, ipId, reservation.lockToken);
				} catch (error) {
					this.#logger.error({
						error: errorSummary(error),
						event: 'asset_extraction.lock_release_failed',
						requestId
					}, 'Asset extraction lock release failed');
				}
			}

			status = 200;
			code = 'OK';
			return jsonResponse(toPublicExtraction(result.suggestion), status, requestId);
		} catch (error) {
			const known = error instanceof AnalysisError ? error : unavailable(error);
			status = known.status;
			code = known.code;
			if (known.cause !== undefined) failure = errorSummary(known.cause);
			return jsonResponse(
				{ error: { code: known.code, message: known.message } },
				known.status,
				requestId,
				known.retryAfterSeconds
			);
		} finally {
			const event: SafeAnalysisLog & { event: string } = {
				event: 'asset_extraction.request_completed',
				timestamp: startedAt.toISOString(),
				requestId,
				...(kind ? { kind } : {}),
				sizeBytes: bytes.byteLength,
				...(pageCount === undefined ? {} : { pageCount }),
				latencyMilliseconds: Math.max(0, this.#now().getTime() - startedAt.getTime()),
				status,
				code,
				...(failure ? { error: failure } : {}),
				inputTokens: usage.inputTokens,
				outputTokens: usage.outputTokens,
				totalTokens: usage.totalTokens
			};
			if (status >= 500) {
				this.#logger.error(event, 'Asset extraction request failed');
			} else if (status >= 400) {
				this.#logger.warn(event, 'Asset extraction request rejected');
			} else {
				this.#logger.info(event, 'Asset extraction request completed');
			}
		}
	}
}

function parseQuery(request: Request): { kind: AnalysisKind; locale: string } {
	if (request.method !== 'POST') {
		throw new AnalysisError('INVALID_ANALYSIS_INPUT', 400, 'Only POST is supported');
	}
	const url = new URL(request.url);
	const keys = [...url.searchParams.keys()];
	if (keys.length !== 2 || new Set(keys).size !== 2 ||
		url.searchParams.getAll('kind').length !== 1 ||
		url.searchParams.getAll('locale').length !== 1 ||
		!keys.every((key) => key === 'kind' || key === 'locale')) {
		throw new AnalysisError('INVALID_ANALYSIS_INPUT', 400, 'kind and locale are required');
	}
	const kind = url.searchParams.get('kind');
	if (kind !== 'object-photo' && kind !== 'invoice') {
		throw new AnalysisError('INVALID_ANALYSIS_INPUT', 400, 'kind is invalid');
	}
	const rawLocale = url.searchParams.get('locale');
	if (!rawLocale || rawLocale.length > 100) {
		throw new AnalysisError('INVALID_ANALYSIS_INPUT', 400, 'locale is invalid');
	}
	try {
		const [locale] = Intl.getCanonicalLocales(rawLocale);
		if (!locale) throw new Error('Locale is empty');
		return { kind, locale };
	} catch (error) {
		throw new AnalysisError('INVALID_ANALYSIS_INPUT', 400, 'locale is invalid', undefined, { cause: error });
	}
}

function normalizedContentType(value: string | null): string | null {
	return value?.trim().toLowerCase() ?? null;
}

function parseContentLength(value: string | null): number | null {
	if (value === null || !/^[1-9]\d*$/.test(value)) return null;
	const result = Number(value);
	return Number.isSafeInteger(result) ? result : null;
}

function throwForAttemptDecision(decision: AttemptDecision): void {
	if (decision.kind === 'accepted') return;
	if (decision.kind === 'quarantined') {
		throw new AnalysisError(
			'ANALYSIS_QUARANTINED', 403, 'Asset analysis is temporarily suspended',
			decision.retryAfterSeconds
		);
	}
	throw new AnalysisError(
		'ANALYSIS_RATE_LIMITED', 429, 'Too many asset analysis requests',
		decision.retryAfterSeconds
	);
}

function throwForReservationDecision(decision: ReservationDecision): void {
	if (decision.kind === 'accepted') return;
	if (decision.kind === 'quarantined') {
		throw new AnalysisError(
			'ANALYSIS_QUARANTINED', 403, 'Asset analysis is temporarily suspended',
			decision.retryAfterSeconds
		);
	}
	if (decision.kind === 'daily_limited' || decision.kind === 'ip_daily_limited') {
		throw new AnalysisError(
			'ANALYSIS_DAILY_LIMIT_REACHED', 429, 'The daily asset analysis limit has been reached',
			decision.retryAfterSeconds
		);
	}
	throw new AnalysisError(
		'ANALYSIS_RATE_LIMITED', 429, 'Another asset analysis is already running',
		decision.retryAfterSeconds
	);
}

function unavailable(cause: unknown): AnalysisError {
	return new AnalysisError(
		'ANALYSIS_UNAVAILABLE', 503, 'Asset analysis is temporarily unavailable',
		undefined, { cause }
	);
}

function jsonResponse(
	value: unknown,
	status: number,
	requestId: string,
	retryAfterSeconds?: number
): Response {
	const headers = new Headers({
		'Cache-Control': 'no-store',
		'Content-Type': 'application/json',
		'X-Content-Type-Options': 'nosniff',
		'X-Request-Id': requestId
	});
	if (retryAfterSeconds !== undefined) headers.set('Retry-After', String(retryAfterSeconds));
	return new Response(JSON.stringify(value), { status, headers });
}
