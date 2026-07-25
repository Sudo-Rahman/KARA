import { env } from '$env/dynamic/private';

import { MetalsSpotCache } from './cache';
import { goldApiKeyFromEnvironment } from './config';

let cache: MetalsSpotCache | undefined;

export function metalsSpotCache(): MetalsSpotCache {
	cache ??= new MetalsSpotCache({ apiKey: goldApiKeyFromEnvironment(env) });
	return cache;
}
