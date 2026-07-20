import type { RequestHandler } from './$types';
import { publicConfig } from '$lib/config';
import { buildSitemap } from '$lib/config/sitemap';

export const GET: RequestHandler = ({ url }) => {
	const baseUrl = publicConfig.siteUrl ?? url.origin;

	return new Response(buildSitemap(baseUrl), {
		headers: {
			'cache-control': 'public, max-age=3600',
			'content-type': 'application/xml; charset=utf-8'
		}
	});
};
