import type { RequestHandler } from './$types';

import { handleSpotRequest } from '$lib/server/metals-spot/handler';
import { metalsSpotCache } from '$lib/server/metals-spot/service';

export const GET: RequestHandler = ({ request, locals }) => handleSpotRequest(
	request,
	metalsSpotCache(),
	{
		logger: locals.logger.child({ feature: 'metals-spot' }),
		requestId: locals.requestId
	}
);

export const HEAD: RequestHandler = GET;
