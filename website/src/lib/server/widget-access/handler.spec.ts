import { describe, expect, it, vi } from 'vitest';
import { handleWidgetQuotes } from './handler';

describe('widget market endpoint', () => {
	it('rejects unauthenticated traffic before reading market data', async () => {
		const get = vi.fn();
		const response = await handleWidgetQuotes(new Request('https://example.test/widget/v1/quotes.json'),
			{ authenticate: async () => false }, get);
		expect(response.status).toBe(401);
		expect(get).not.toHaveBeenCalled();
	});
	it('limits currencies and never forwards arbitrary parameters upstream', async () => {
		const get = vi.fn();
		const response = await handleWidgetQuotes(new Request('https://example.test/widget/v1/quotes.json?currencies=EVIL'),
			{ authenticate: async () => true }, get);
		expect(response.status).toBe(400);
		expect(get).not.toHaveBeenCalled();
	});
	it('retrieves EUR and required purchase currencies with unchanged source dates', async () => {
		const sourceUpdatedAt = '2026-09-07T12:00:00Z';
		const get = vi.fn(async (metal, currency) => ({
			quote: { schemaVersion: 1 as const, metal, currency, price: '100.000000',
				unit: { code: 'troy_ounce' as const, grams: '31.1034768' as const }, sourceUpdatedAt },
			cacheStatus: 'HIT' as const
		}));
		const response = await handleWidgetQuotes(new Request('https://example.test/widget/v1/quotes.json?currencies=USD,USD'),
			{ authenticate: async () => true }, get);
		expect(response.status).toBe(200);
		const payload = await response.json();
		expect(payload.spots).toHaveLength(8);
		expect(payload.spots.every((quote: { sourceUpdatedAt: string }) => quote.sourceUpdatedAt === sourceUpdatedAt)).toBe(true);
		expect(response.headers.get('Cache-Control')).toBe('no-store');
	});
});
