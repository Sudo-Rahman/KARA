import { METALS, type Currency } from '../metals-spot/contracts';
import type { SpotCacheResult } from '../metals-spot/cache';
import type { WidgetAccessService } from './service';

export async function handleWidgetQuotes(
	request: Request,
	access: Pick<WidgetAccessService, 'authenticate'>,
	get: (metal: typeof METALS[number], currency: Currency) => Promise<SpotCacheResult>
): Promise<Response> {
	const headers = { 'Cache-Control': 'no-store' };
	if (!await access.authenticate(request.headers.get('Authorization'))) {
		return Response.json({ error: 'widget_access_required' }, { status: 401, headers });
	}
	const requested = new URL(request.url).searchParams.get('currencies') ?? 'EUR';
	const currencies = [...new Set(['EUR', ...requested.split(',')])];
	if (currencies.some(currency => !['EUR', 'USD', 'CHF', 'GBP'].includes(currency))) {
		return Response.json({ error: 'invalid_currency' }, { status: 400, headers });
	}
	const results = await Promise.all(currencies.flatMap(currency =>
		METALS.map(metal => get(metal, currency as Currency))));
	return Response.json({ schemaVersion: 1, spots: results.map(result => result.quote) }, { headers });
}
