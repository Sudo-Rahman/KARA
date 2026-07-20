import type { CachedResource } from './cache';

function matchesEtag(header: string | null, etag: string): boolean {
	if (header === null) return false;
	return header.split(',').some((candidate) => {
		const value = candidate.trim();
		return value === '*' || value === etag || value === `W/${etag}`;
	});
}

function headersFor(resource: CachedResource): Headers {
	return new Headers({
		'Access-Control-Allow-Origin': '*',
		'Cache-Control': 'public, max-age=0, must-revalidate',
		'Content-Length': String(resource.bytes.byteLength),
		'Content-Type': 'application/json',
		ETag: resource.etag,
		'X-Content-Type-Options': 'nosniff'
	});
}

export function publicationResponse(resource: CachedResource, request: Request): Response {
	const headers = headersFor(resource);
	if (matchesEtag(request.headers.get('if-none-match'), resource.etag)) {
		return new Response(null, { status: 304, headers });
	}
	if (request.method === 'HEAD') {
		return new Response(null, { status: 200, headers });
	}
	return new Response(Buffer.from(resource.bytes), { status: 200, headers });
}
