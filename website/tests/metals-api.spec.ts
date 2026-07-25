import { expect, test } from '@playwright/test';

test('requires App Attest for every v1 API route', async ({ request }) => {
	for (const path of [
		'/v1/manifest.json',
		'/v1/market-data/bootstrap.json',
		'/v1/metals-monthly.json',
		'/v1/metals-spot.json?metal=XAU&currency=EUR',
		'/en/v1/manifest.json'
	]) {
		const response = await request.get(path);
		expect(response.status()).toBe(401);
		expect(await response.json()).toEqual({
			error: {
				code: 'app_attest_required',
				message: 'App Attest headers are required'
			}
		});
	}

	const head = await request.head('/v1/metals-monthly.json');
	expect(head.status()).toBe(401);
	const bootstrapHead = await request.head('/v1/market-data/bootstrap.json');
	expect(bootstrapHead.status()).toBe(401);
});

test('keeps liveness public', async ({ request }) => {
	const response = await request.get('/healthz');
	expect(response.status()).toBe(200);
	expect(await response.text()).toBe('ok');

	const readiness = await request.get('/readyz');
	expect(readiness.status()).toBe(503);
	expect(await readiness.text()).toBe('not ready');
});
