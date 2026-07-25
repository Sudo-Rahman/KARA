import { sequence } from '@sveltejs/kit/hooks';
import type { Handle, ServerInit } from '@sveltejs/kit';
import '$lib/config';
import { authenticateAppAttestRequest } from '$lib/server/app-attest/middleware';
import { appAttestService } from '$lib/server/app-attest/runtime';
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
	if (deLocalizeUrl(event.url).pathname.startsWith('/v1/')) {
		const rejection = await authenticateAppAttestRequest(event.request, appAttestService);
		if (rejection) return rejection;
	}
	return resolve(event);
};

export const handle: Handle = sequence(handleAppAttest, handleParaglide);
