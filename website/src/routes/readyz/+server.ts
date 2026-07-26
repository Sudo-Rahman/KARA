import type { RequestHandler } from './$types';

import { appAttestService } from '$lib/server/app-attest/runtime';
import { appAttestIPRateLimiter } from '$lib/server/app-attest/ip-rate-limit-runtime';
import { assetExtractionReady } from '$lib/server/asset-extraction/runtime';

export const GET: RequestHandler = async () => {
	try {
		await Promise.all([
			appAttestService().ready(),
			appAttestIPRateLimiter().ready(),
			assetExtractionReady()
		]);
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
