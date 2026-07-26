export type AssetExtractionConfig =
	| { enabled: false }
	| {
		enabled: true;
		openAIAPIKey: string;
		redisURL: string;
		hmacSecret: Buffer;
		redisPrefix: string;
	};

export function loadAssetExtractionConfig(
	source: Record<string, string | undefined>
): AssetExtractionConfig {
	const enabledValue = source.ASSET_EXTRACTION_ENABLED?.trim().toLowerCase();
	if (enabledValue === undefined || enabledValue === '' || enabledValue === 'false') {
		return { enabled: false };
	}
	if (enabledValue !== 'true') {
		throw new Error('ASSET_EXTRACTION_ENABLED must be true or false');
	}

	const encodedSecret = required(source, 'ASSET_EXTRACTION_HMAC_SECRET');
	if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encodedSecret)) {
		throw new Error('ASSET_EXTRACTION_HMAC_SECRET must be canonical base64');
	}
	const hmacSecret = Buffer.from(encodedSecret, 'base64');
	if (hmacSecret.length < 32 || hmacSecret.toString('base64') !== encodedSecret) {
		throw new Error('ASSET_EXTRACTION_HMAC_SECRET must contain at least 256 bits');
	}

	const redisPrefix = source.ASSET_EXTRACTION_REDIS_PREFIX?.trim() || 'kara:asset-extraction';
	if (!/^[a-z0-9:-]{1,100}$/i.test(redisPrefix)) {
		throw new Error('ASSET_EXTRACTION_REDIS_PREFIX is invalid');
	}
	return {
		enabled: true,
		openAIAPIKey: required(source, 'OPENAI_API_KEY'),
		redisURL: required(source, 'REDIS_URL'),
		hmacSecret,
		redisPrefix
	};
}

function required(source: Record<string, string | undefined>, name: string): string {
	const value = source[name]?.trim();
	if (!value) throw new Error(`${name} is required`);
	return value;
}

