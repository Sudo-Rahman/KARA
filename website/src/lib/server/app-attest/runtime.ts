import { env } from '$env/dynamic/private';

import { loadAppAttestConfig } from './config';
import { RedisAppAttestStore } from './redis-store';
import { AppAttestAuthService } from './service';
import { NodeAppAttestVerifier } from './verifier';

let service: AppAttestAuthService | undefined;

export function appAttestService(): AppAttestAuthService {
	if (!service) {
		const config = loadAppAttestConfig(env);
		service = new AppAttestAuthService({
			store: new RedisAppAttestStore(config.redisURL),
			verifier: new NodeAppAttestVerifier(config)
		});
	}
	return service;
}
