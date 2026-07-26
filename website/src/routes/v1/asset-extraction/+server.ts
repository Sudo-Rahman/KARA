import { randomUUID } from 'node:crypto';

import type { RequestHandler } from './$types';

import { AnalysisError } from '$lib/server/asset-extraction/errors';
import { assetExtractionService } from '$lib/server/asset-extraction/runtime';

export const POST: RequestHandler = async ({ request, locals, getClientAddress }) => {
	if (!locals.appAttest) {
		locals.logger.error({
			code: 'ANALYSIS_UNAVAILABLE',
			event: 'asset_extraction.missing_principal',
			status: 503
		}, 'Asset extraction principal is missing after authentication');
		return errorResponse(
			new AnalysisError('ANALYSIS_UNAVAILABLE', 503, 'Asset analysis is temporarily unavailable'),
			locals.requestId
		);
	}
	try {
		return await assetExtractionService().handle({
			request,
			principal: locals.appAttest,
			clientAddress: getClientAddress(),
			requestId: locals.requestId
		});
	} catch (error) {
		locals.logger.error({
			code: error instanceof AnalysisError ? error.code : 'ANALYSIS_UNAVAILABLE',
			event: 'asset_extraction.route_failed',
			status: error instanceof AnalysisError ? error.status : 503
		}, 'Asset extraction route failed before processing');
		return errorResponse(error, locals.requestId);
	}
};

function errorResponse(error: unknown, requestId: string = randomUUID()): Response {
	const known = error instanceof AnalysisError
		? error
		: new AnalysisError('ANALYSIS_UNAVAILABLE', 503, 'Asset analysis is temporarily unavailable');
	const headers = new Headers({
		'Cache-Control': 'no-store',
		'Content-Type': 'application/json',
		'X-Content-Type-Options': 'nosniff',
		'X-Request-Id': requestId
	});
	if (known.retryAfterSeconds !== undefined) {
		headers.set('Retry-After', String(known.retryAfterSeconds));
	}
	return new Response(JSON.stringify({ error: { code: known.code, message: known.message } }), {
		status: known.status,
		headers
	});
}
