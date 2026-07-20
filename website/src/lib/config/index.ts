import { dev } from '$app/environment';
import { env } from '$env/dynamic/public';
import { loadPublicConfig, type PublicConfigSource } from './public';

export {
	PublicConfigError,
	loadPublicConfig,
	publicConfigKeys,
	resolvePublicConfig,
	type PublicConfig,
	type PublicConfigIssue,
	type PublicConfigKey,
	type PublicConfigMode,
	type PublicConfigSource
} from './public';

export const publicConfig = loadPublicConfig(
	env as PublicConfigSource,
	dev ? 'development' : 'production'
);
