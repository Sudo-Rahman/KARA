import type { RequestHandler } from './$types';

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

export const GET: RequestHandler = ({ request }) =>
	handleMarketDataBootstrapRequest(request, provider);

export const HEAD: RequestHandler = GET;
