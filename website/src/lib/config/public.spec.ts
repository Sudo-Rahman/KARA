import { describe, expect, it } from 'vitest';
import {
	PublicConfigError,
	loadPublicConfig,
	publicConfigKeys,
	resolvePublicConfig,
	type PublicConfigSource
} from './public';

const validSource = {
	PUBLIC_SITE_URL: 'https://kara.app/',
	PUBLIC_APP_STORE_URL: 'https://apps.apple.com/app/kara',
	PUBLIC_GOOGLE_PLAY_URL: 'https://play.google.com/store/apps/details?id=app.kara',
	PUBLIC_SUPPORT_EMAIL: 'support@kara.app',
	PUBLIC_LEGAL_NAME: 'Kara SAS'
} satisfies PublicConfigSource;

describe('public configuration', () => {
	it('keeps development usable with disabled values when variables are absent', () => {
		const config = loadPublicConfig({}, 'development');

		expect(config.isComplete).toBe(false);
		expect(config.appStoreUrl).toBeNull();
		expect(config.googlePlayUrl).toBeNull();
		expect(config.issues.map(({ key }) => key)).toEqual(publicConfigKeys);
	});

	it('normalizes complete valid configuration', () => {
		const config = resolvePublicConfig(validSource);

		expect(config).toMatchObject({
			siteUrl: 'https://kara.app',
			appStoreUrl: 'https://apps.apple.com/app/kara',
			googlePlayUrl: 'https://play.google.com/store/apps/details?id=app.kara',
			supportEmail: 'support@kara.app',
			legalName: 'Kara SAS',
			isComplete: true,
			issues: []
		});
	});

	it.each(['production', 'test'] as const)('rejects incomplete %s configuration', (mode) => {
		expect(() => loadPublicConfig({}, mode)).toThrow(PublicConfigError);
	});

	it('rejects invalid URLs and email addresses in strict mode', () => {
		expect(() =>
			loadPublicConfig(
				{
					...validSource,
					PUBLIC_APP_STORE_URL: 'javascript:alert(1)',
					PUBLIC_SUPPORT_EMAIL: 'not-an-email'
				},
				'production'
			)
		).toThrowError(/PUBLIC_APP_STORE_URL[\s\S]*PUBLIC_SUPPORT_EMAIL/);
	});
});
