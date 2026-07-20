import { createHash } from 'node:crypto';

import { expect, test } from '@playwright/test';

test('serves a coherent metals publication with conditional caching', async ({ request }) => {
	const manifestResponse = await request.get('/v1/manifest.json');
	expect(manifestResponse.status()).toBe(200);
	expect(manifestResponse.headers()['content-type']).toBe('application/json');
	expect(manifestResponse.headers()['cache-control']).toBe('public, max-age=0, must-revalidate');
	expect(manifestResponse.headers()['access-control-allow-origin']).toBe('*');
	expect(manifestResponse.headers()['x-content-type-options']).toBe('nosniff');

	const manifest = await manifestResponse.json();
	const dataResponse = await request.get('/v1/metals-monthly.json');
	expect(dataResponse.status()).toBe(200);
	const data = await dataResponse.body();
	const sha256 = createHash('sha256').update(data).digest('hex');
	expect(manifest.dataVersion).toBe(sha256);
	expect(manifest.file.sha256).toBe(sha256);
	expect(manifest.file.bytes).toBe(data.byteLength);

	const etag = dataResponse.headers().etag;
	expect(etag).toBe(`"${sha256}"`);
	const notModified = await request.get('/v1/metals-monthly.json', {
		headers: { 'If-None-Match': etag }
	});
	expect(notModified.status()).toBe(304);
	expect((await notModified.body()).byteLength).toBe(0);

	const head = await request.head('/v1/metals-monthly.json');
	expect(head.status()).toBe(200);
	expect(head.headers().etag).toBe(etag);
	expect(head.headers()['content-length']).toBe(String(data.byteLength));
	expect((await head.body()).byteLength).toBe(0);
});
