import type { AppAttestEnvironment } from './types';

export interface AppAttestConfig {
	redisURL: string;
	teamIdentifier: string;
	bundleIdentifier: string;
	environment: AppAttestEnvironment;
}

export function loadAppAttestConfig(source: Record<string, string | undefined>): AppAttestConfig {
	const redisURL = required(source, 'REDIS_URL');
	const teamIdentifier = required(source, 'APP_ATTEST_TEAM_ID');
	const bundleIdentifier = required(source, 'APP_ATTEST_BUNDLE_ID');
	const environment = required(source, 'APP_ATTEST_ENVIRONMENT');
	if (environment !== 'development' && environment !== 'production') {
		throw new Error('APP_ATTEST_ENVIRONMENT must be development or production');
	}
	return { redisURL, teamIdentifier, bundleIdentifier, environment };
}

function required(source: Record<string, string | undefined>, name: string): string {
	const value = source[name]?.trim();
	if (!value) throw new Error(`${name} is required`);
	return value;
}
