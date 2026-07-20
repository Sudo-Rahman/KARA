import type { RequestHandler } from './$types';

import { publicationResponse } from '$lib/server/metals-data/response';
import { metalsDataCache } from '$lib/server/metals-data/service';

export const GET: RequestHandler = ({ request }) =>
	publicationResponse(metalsDataCache.current().data, request);

export const HEAD: RequestHandler = GET;
