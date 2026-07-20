import type { RequestHandler } from './$types';
import { publicConfig } from '$lib/config';

export const GET: RequestHandler = ({ url }) => {
	const origin = publicConfig.siteUrl ?? url.origin;
	const body = ['User-agent: *', 'Allow: /', `Sitemap: ${origin}/sitemap.xml`, ''].join('\n');

	return new Response(body, {
		headers: {
			'cache-control': 'public, max-age=3600',
			'content-type': 'text/plain; charset=utf-8'
		}
	});
};
