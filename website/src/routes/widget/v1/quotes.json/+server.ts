import type { RequestHandler } from './$types';
import { widgetAccessService } from '$lib/server/widget-access/runtime';
import { handleWidgetQuotes } from '$lib/server/widget-access/handler';
import { metalsSpotCache } from '$lib/server/metals-spot/service';
export const GET: RequestHandler = async ({ request, locals }) => {
	try {
		return await handleWidgetQuotes(request, widgetAccessService(),
			(metal, currency) => metalsSpotCache().get(metal, currency));
	} catch {
		locals.logger.error({ event: 'widget.refresh_failed' }, 'Widget market refresh failed');
		return Response.json({ error: 'widget_refresh_unavailable' },
			{ status: 503, headers: { 'Cache-Control': 'no-store' } });
	}
};
