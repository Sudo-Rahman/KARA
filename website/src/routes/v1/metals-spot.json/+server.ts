import type { RequestHandler } from './$types';

import { handleSpotRequest } from '$lib/server/metals-spot/handler';
import { metalsSpotCache } from '$lib/server/metals-spot/service';

export const GET: RequestHandler = ({ request }) => handleSpotRequest(request, metalsSpotCache);

export const HEAD: RequestHandler = GET;

