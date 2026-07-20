export const publicConfigKeys = [
	'PUBLIC_SITE_URL',
	'PUBLIC_APP_STORE_URL',
	'PUBLIC_GOOGLE_PLAY_URL',
	'PUBLIC_SUPPORT_EMAIL',
	'PUBLIC_LEGAL_NAME'
] as const;

export type PublicConfigKey = (typeof publicConfigKeys)[number];
export type PublicConfigMode = 'development' | 'production' | 'test';
export type PublicConfigSource = Partial<Record<PublicConfigKey, string | undefined>>;

export interface PublicConfigIssue {
	key: PublicConfigKey;
	reason: 'missing' | 'invalid';
	message: string;
}

export interface PublicConfig {
	siteUrl: string | null;
	appStoreUrl: string | null;
	googlePlayUrl: string | null;
	supportEmail: string | null;
	legalName: string | null;
	issues: readonly PublicConfigIssue[];
	isComplete: boolean;
}

export class PublicConfigError extends Error {
	readonly issues: readonly PublicConfigIssue[];

	constructor(issues: readonly PublicConfigIssue[]) {
		super(
			`Invalid public configuration:\n${issues.map(({ key, message }) => `- ${key}: ${message}`).join('\n')}`
		);
		this.name = 'PublicConfigError';
		this.issues = issues;
	}
}

function clean(value: string | undefined): string | null {
	const cleaned = value?.trim();
	return cleaned ? cleaned : null;
}

function parseWebUrl(
	key: PublicConfigKey,
	value: string | null,
	issues: PublicConfigIssue[]
): string | null {
	if (!value) {
		issues.push({ key, reason: 'missing', message: 'is required' });
		return null;
	}

	try {
		const parsed = new URL(value);
		if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
			throw new Error('unsupported protocol');
		}

		if (parsed.username || parsed.password) {
			throw new Error('credentials are not allowed');
		}

		return parsed.href.replace(/\/$/, '');
	} catch {
		issues.push({ key, reason: 'invalid', message: 'must be an absolute HTTP(S) URL' });
		return null;
	}
}

function parseEmail(value: string | null, issues: PublicConfigIssue[]): string | null {
	const key = 'PUBLIC_SUPPORT_EMAIL';
	if (!value) {
		issues.push({ key, reason: 'missing', message: 'is required' });
		return null;
	}

	if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
		issues.push({ key, reason: 'invalid', message: 'must be a valid email address' });
		return null;
	}

	return value;
}

/**
 * Resolves public configuration without throwing. This makes missing development
 * store links render as explicit disabled states instead of broken anchors.
 */
export function resolvePublicConfig(source: PublicConfigSource): PublicConfig {
	const issues: PublicConfigIssue[] = [];
	const siteUrl = parseWebUrl('PUBLIC_SITE_URL', clean(source.PUBLIC_SITE_URL), issues);
	const appStoreUrl = parseWebUrl(
		'PUBLIC_APP_STORE_URL',
		clean(source.PUBLIC_APP_STORE_URL),
		issues
	);
	const googlePlayUrl = parseWebUrl(
		'PUBLIC_GOOGLE_PLAY_URL',
		clean(source.PUBLIC_GOOGLE_PLAY_URL),
		issues
	);
	const supportEmail = parseEmail(clean(source.PUBLIC_SUPPORT_EMAIL), issues);
	const legalName = clean(source.PUBLIC_LEGAL_NAME);

	if (!legalName) {
		issues.push({ key: 'PUBLIC_LEGAL_NAME', reason: 'missing', message: 'is required' });
	}

	const config = {
		siteUrl,
		appStoreUrl,
		googlePlayUrl,
		supportEmail,
		legalName,
		issues,
		isComplete: issues.length === 0
	} satisfies PublicConfig;

	return config;
}

/**
 * Production and test callers use strict validation; development remains usable
 * with intentionally disabled links while environment values are being prepared.
 */
export function loadPublicConfig(
	source: PublicConfigSource,
	mode: PublicConfigMode = 'development'
): PublicConfig {
	const config = resolvePublicConfig(source);

	if (mode !== 'development' && !config.isComplete) {
		throw new PublicConfigError(config.issues);
	}

	return config;
}
