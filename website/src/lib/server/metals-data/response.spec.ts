import { describe, expect, test } from 'vitest';

import { publicationResponse } from './response';

const resource = {
	bytes: new TextEncoder().encode('{"ok":true}\n'),
	etag: '"abc123"'
};

describe('publicationResponse', () => {
	test('returns the exact cached JSON bytes and public API headers', async () => {
		const response = publicationResponse(resource, new Request('https://kara.test/v1/data.json'));

		expect(response.status).toBe(200);
		expect(new Uint8Array(await response.arrayBuffer())).toEqual(resource.bytes);
		expect(response.headers.get('content-type')).toBe('application/json');
		expect(response.headers.get('cache-control')).toBe('public, max-age=0, must-revalidate');
		expect(response.headers.get('access-control-allow-origin')).toBe('*');
		expect(response.headers.get('x-content-type-options')).toBe('nosniff');
		expect(response.headers.get('etag')).toBe(resource.etag);
		expect(response.headers.get('content-length')).toBe(String(resource.bytes.byteLength));
	});

	test('returns an empty 304 when If-None-Match contains the current ETag', async () => {
		const request = new Request('https://kara.test/v1/data.json', {
			headers: { 'if-none-match': `"other", ${resource.etag}` }
		});
		const response = publicationResponse(resource, request);

		expect(response.status).toBe(304);
		expect(await response.text()).toBe('');
		expect(response.headers.get('etag')).toBe(resource.etag);
	});

	test('returns headers without a body for HEAD', async () => {
		const response = publicationResponse(
			resource,
			new Request('https://kara.test/v1/data.json', { method: 'HEAD' })
		);

		expect(response.status).toBe(200);
		expect(await response.text()).toBe('');
		expect(response.headers.get('content-length')).toBe(String(resource.bytes.byteLength));
		expect(response.headers.get('etag')).toBe(resource.etag);
	});
});
