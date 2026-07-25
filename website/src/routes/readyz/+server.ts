import type { RequestHandler } from './$types';

import { appAttestService } from '$lib/server/app-attest/runtime';

export const GET: RequestHandler = async () => {
	try {
		await appAttestService().ready();
		return new Response('ready', {
			status: 200,
			headers: { 'Cache-Control': 'no-store', 'Content-Type': 'text/plain; charset=utf-8' }
		});
	} catch {
		return new Response('not ready', {
			status: 503,
			headers: { 'Cache-Control': 'no-store', 'Content-Type': 'text/plain; charset=utf-8' }
		});
	}
};

export const HEAD: RequestHandler = GET;
