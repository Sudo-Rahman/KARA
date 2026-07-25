import type { RequestHandler } from './$types';

export const GET: RequestHandler = () => new Response('ok', {
	status: 200,
	headers: { 'Cache-Control': 'no-store', 'Content-Type': 'text/plain; charset=utf-8' }
});

export const HEAD: RequestHandler = GET;
