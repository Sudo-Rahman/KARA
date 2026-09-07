import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ issue: vi.fn(), bootstrap: vi.fn() }));
vi.mock('$lib/server/widget-access/runtime', () => ({ widgetAccessService: () => ({ issue: mocks.issue }) }));
vi.mock('$lib/server/metals-data/service', () => ({ metalsDataCache: {} }));
vi.mock('$lib/server/metals-spot/service', () => ({ metalsSpotCache: vi.fn() }));
vi.mock('$lib/server/market-data-bootstrap/handler', () => ({ handleMarketDataBootstrapRequest: mocks.bootstrap }));
import { GET } from '../../../routes/v1/market-data/bootstrap.json/+server';

describe('host provisions autonomous widget access', () => {
	beforeEach(() => {
		vi.resetAllMocks();
		mocks.bootstrap.mockResolvedValue(new Response('{}'));
		mocks.issue.mockResolvedValue('scoped-widget-token');
	});
	function event(attested: boolean, method = 'GET') {
		return {
			request: new Request('https://example.test/v1/market-data/bootstrap.json', { method }),
			locals: { appAttest: attested ? { keyId: 'device' } : undefined,
				logger: { child: () => ({}), warn: vi.fn() }, requestId: 'request' }
		} as unknown as Parameters<typeof GET>[0];
	}
	it('issues only after an authenticated successful GET', async () => {
		const response = await GET(event(true));
		expect(mocks.issue).toHaveBeenCalledWith('device', null);
		expect(response.headers.get('X-Kara-Widget-Token')).toBe('scoped-widget-token');
		expect(response.headers.get('Cache-Control')).toBe('no-store');
	});
	it('never grants unauthenticated callers or HEAD requests', async () => {
		await GET(event(false));
		await GET(event(true, 'HEAD'));
		expect(mocks.issue).not.toHaveBeenCalled();
	});
	it('keeps the host market response usable if grant storage fails', async () => {
		mocks.issue.mockRejectedValue(new Error('offline'));
		const response = await GET(event(true));
		expect(response.status).toBe(200);
		expect(response.headers.has('X-Kara-Widget-Token')).toBe(false);
	});
});
