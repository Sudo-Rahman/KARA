import { building } from '$app/environment';
import { env } from '$env/dynamic/private';

import { MetalsSpotCache } from './cache';
import { goldApiKeyFromEnvironment } from './config';

export const metalsSpotCache = new MetalsSpotCache({
	apiKey: building ? 'unused-during-sveltekit-build' : goldApiKeyFromEnvironment(env)
});
