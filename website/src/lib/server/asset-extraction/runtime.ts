import { env } from '$env/dynamic/private';

import { loadAssetExtractionConfig } from './config';
import { AnalysisError } from './errors';
import { createOpenAIAssetExtractor } from './openai';
import { RedisAnalysisQuotaStore } from './redis-quota';
import { AssetExtractionService } from './service';
import { logger } from '../logger';

let service: AssetExtractionService | undefined;

export function assetExtractionService(): AssetExtractionService {
	const config = loadAssetExtractionConfig(env);
	if (!config.enabled) {
		throw new AnalysisError(
			'ANALYSIS_UNAVAILABLE',
			503,
			'Asset analysis is temporarily unavailable'
		);
	}
	if (!service) {
		service = new AssetExtractionService({
			hmacSecret: config.hmacSecret,
			quota: new RedisAnalysisQuotaStore(config.redisURL, config.redisPrefix),
			extractor: createOpenAIAssetExtractor(config.openAIAPIKey),
			logger: logger.child({ component: 'asset-extraction' })
		});
	}
	return service;
}

export async function assetExtractionReady(): Promise<void> {
	const config = loadAssetExtractionConfig(env);
	if (!config.enabled) return;
	await assetExtractionService().ready();
}
