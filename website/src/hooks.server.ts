import { sequence } from '@sveltejs/kit/hooks';
import type { Handle, HandleServerError, ServerInit } from '@sveltejs/kit';
import { randomUUID } from 'node:crypto';
import '$lib/config';
import { authenticateAppAttestRequest } from '$lib/server/app-attest/middleware';
import { appAttestService } from '$lib/server/app-attest/runtime';
import { appAttestIPRateLimiter } from '$lib/server/app-attest/ip-rate-limit-runtime';
import { AppAttestError } from '$lib/server/app-attest/errors';
import { appAttestErrorResponse } from '$lib/server/app-attest/http';
import { startMetalsDataRefresh } from '$lib/server/metals-data/service';
import { logger } from '$lib/server/logger';
import { deLocalizeUrl, getTextDirection } from '$lib/paraglide/runtime';
import { paraglideMiddleware } from '$lib/paraglide/server';

export const init: ServerInit = () => {
	logger.info({ event: 'server.initialized' }, 'Kara backend initialized');
	startMetalsDataRefresh();
};

const handleRequestLogging: Handle = async ({ event, resolve }) => {
	const requestId = randomUUID();
	const pathname = deLocalizeUrl(event.url).pathname;
	const shouldLog = pathname.startsWith('/v1/') || pathname.startsWith('/auth/app-attest/');
	const shouldLogCompletion = shouldLog && pathname !== '/v1/asset-extraction';
	const startedAt = performance.now();
	event.locals.requestId = requestId;
	event.locals.logger = logger.child({
		component: 'http',
		method: event.request.method,
		path: pathname,
		requestId
	});

	const response = await resolve(event);
	if (!shouldLog) return response;

	response.headers.set('X-Request-Id', requestId);
	if (!shouldLogCompletion) return response;
	const context = {
		event: 'http.request.completed',
		latencyMilliseconds: Math.max(0, Math.round(performance.now() - startedAt)),
		status: response.status
	};
	if (response.status >= 500) {
		event.locals.logger.error(context, 'Backend request failed');
	} else if (response.status >= 400) {
		event.locals.logger.warn(context, 'Backend request rejected');
	} else {
		event.locals.logger.info(context, 'Backend request completed');
	}
	return response;
};

const handleParaglide: Handle = ({ event, resolve }) => paraglideMiddleware(event.request, ({ request, locale }) => {
	event.request = request;

	return resolve(event, {
		transformPageChunk: ({ html }) => html.replace('%paraglide.lang%', locale).replace('%paraglide.dir%', getTextDirection(locale))
	});
});

const handleAppAttest: Handle = async ({ event, resolve }) => {
	const pathname = deLocalizeUrl(event.url).pathname;
	const isAssetExtraction = pathname === '/v1/asset-extraction';
	const publicEndpoint = pathname === '/auth/app-attest/challenges'
		? 'challenge'
		: pathname === '/auth/app-attest/registrations'
			? 'registration'
			: undefined;
	if (publicEndpoint && event.request.method === 'POST') {
		const requestId = event.locals.requestId;
		try {
			const decision = await appAttestIPRateLimiter().consume({
				endpoint: publicEndpoint,
				clientAddress: event.getClientAddress(),
				requestId,
				nowMilliseconds: Date.now()
			});
			if (decision.kind === 'limited') {
				event.locals.logger.warn({
					event: 'app_attest.rate_limited',
					endpoint: publicEndpoint,
					retryAfterSeconds: decision.retryAfterSeconds
				}, 'App Attest public endpoint rate limit exceeded');
				const response = appAttestErrorResponse(new AppAttestError(
					'app_attest_rate_limited',
					429,
					'Too many App Attest requests'
				));
				response.headers.set('Retry-After', String(decision.retryAfterSeconds));
				response.headers.set('X-Request-Id', requestId);
				return response;
			}
		} catch (error) {
			event.locals.logger.error({
				err: error,
				event: 'app_attest.rate_limit_failed',
				endpoint: publicEndpoint
			}, 'App Attest rate limiter failed closed');
			const response = appAttestErrorResponse(error);
			response.headers.set('X-Request-Id', requestId);
			return response;
		}
	}
	if (pathname.startsWith('/v1/')) {
		const rejection = await authenticateAppAttestRequest(
			event.request,
			appAttestService,
			(principal) => { event.locals.appAttest = principal; },
			event.locals.logger
		);
		if (rejection) {
			if (isAssetExtraction) rejection.headers.set('X-Request-Id', event.locals.requestId);
			return rejection;
		}
	}
	const response = await resolve(event);
	if (isAssetExtraction) {
		if (!response.headers.has('X-Request-Id')) response.headers.set('X-Request-Id', event.locals.requestId);
		response.headers.set('Cache-Control', 'no-store');
		response.headers.set('X-Content-Type-Options', 'nosniff');
	}
	return response;
};

export const handle: Handle = sequence(handleRequestLogging, handleAppAttest, handleParaglide);

export const handleError: HandleServerError = ({ error, event, message, status }) => {
	const requestLogger = event.locals.logger ?? logger.child({
		component: 'http',
		method: event.request.method,
		path: deLocalizeUrl(event.url).pathname,
		requestId: event.locals.requestId ?? randomUUID()
	});
	requestLogger.error({
		err: error,
		event: 'http.request.unhandled_error',
		status
	}, 'Unhandled backend error');
	return { message };
};
