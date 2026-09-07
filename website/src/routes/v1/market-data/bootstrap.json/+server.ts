import type { RequestHandler } from './$types';
import { widgetAccessService } from '$lib/server/widget-access/runtime';

import {
	handleMarketDataBootstrapRequest,
	type MarketDataBootstrapProvider
} from '$lib/server/market-data-bootstrap/handler';
import { metalsDataCache } from '$lib/server/metals-data/service';
import { metalsSpotCache } from '$lib/server/metals-spot/service';

const provider: MarketDataBootstrapProvider = {
	currentManifest: () => metalsDataCache.current().metadata,
	get: (metal, currency) => metalsSpotCache().get(metal, currency)
};

export const GET: RequestHandler = async ({ request, locals }) => {
	const response = await handleMarketDataBootstrapRequest(request, provider, {
		logger: locals.logger.child({ feature: 'market-data-bootstrap' }),
		requestId: locals.requestId
	});

	// Only an App Attest authenticated host can provision read-only widget access.
	if (request.method === 'GET' && locals.appAttest && (response.ok || response.status === 304)) {
		try {
			const token = await widgetAccessService().issue(locals.appAttest.keyId,
				request.headers.get('X-Kara-Widget-Token'));
			response.headers.set('X-Kara-Widget-Token', token);
			response.headers.set('Cache-Control', 'no-store');
		} catch {
			locals.logger.warn({ event: 'widget.grant_failed' }, 'Could not provision widget access');
		}
	}
	return response;
};

export const HEAD: RequestHandler = GET;
