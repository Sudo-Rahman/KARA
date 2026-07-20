import type { Handle, ServerInit } from '@sveltejs/kit';
import { startMetalsDataRefresh } from '$lib/server/metals-data/service';
import { getTextDirection } from '$lib/paraglide/runtime';
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

export const handle: Handle = handleParaglide;
