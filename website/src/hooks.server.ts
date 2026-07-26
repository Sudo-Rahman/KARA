import { sequence } from '@sveltejs/kit/hooks';
import type { Handle, ServerInit } from '@sveltejs/kit';
import { randomUUID } from 'node:crypto';
import '$lib/config';
import { authenticateAppAttestRequest } from '$lib/server/app-attest/middleware';
import { appAttestService } from '$lib/server/app-attest/runtime';
import { appAttestIPRateLimiter } from '$lib/server/app-attest/ip-rate-limit-runtime';
import { AppAttestError } from '$lib/server/app-attest/errors';
import { appAttestErrorResponse } from '$lib/server/app-attest/http';
import { startMetalsDataRefresh } from '$lib/server/metals-data/service';
import { deLocalizeUrl, getTextDirection } from '$lib/paraglide/runtime';
import { paraglideMiddleware } from '$lib/paraglide/server';

export const init: ServerInit = () => {
	startMetalsDataRefresh();
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
		const requestId = randomUUID();
		try {
			const decision = await appAttestIPRateLimiter().consume({
				endpoint: publicEndpoint,
				clientAddress: event.getClientAddress(),
				requestId,
				nowMilliseconds: Date.now()
			});
			if (decision.kind === 'limited') {
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
			const response = appAttestErrorResponse(error);
			response.headers.set('X-Request-Id', requestId);
			return response;
		}
	}
	if (pathname.startsWith('/v1/')) {
		const rejection = await authenticateAppAttestRequest(
			event.request,
			appAttestService,
			(principal) => { event.locals.appAttest = principal; }
		);
		if (rejection) {
			if (isAssetExtraction) rejection.headers.set('X-Request-Id', randomUUID());
			return rejection;
		}
	}
	const response = await resolve(event);
	if (isAssetExtraction) {
		if (!response.headers.has('X-Request-Id')) response.headers.set('X-Request-Id', randomUUID());
		response.headers.set('Cache-Control', 'no-store');
		response.headers.set('X-Content-Type-Options', 'nosniff');
	}
	return response;
};

export const handle: Handle = sequence(handleAppAttest, handleParaglide);
