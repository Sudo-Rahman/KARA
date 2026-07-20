import { describe, expect, it } from 'vitest';
import { buildSitemap, sitemapPaths } from './sitemap';

describe('sitemap', () => {
	it('contains every French and English public route exactly once as a location', () => {
		const sitemap = buildSitemap('https://kara.app');

		expect(sitemapPaths).toEqual([
			'/',
			'/en',
			'/privacy',
			'/en/privacy',
			'/support',
			'/en/support'
		]);
		for (const path of sitemapPaths) {
			const url = path === '/' ? 'https://kara.app/' : `https://kara.app${path}`;
			expect(sitemap.match(new RegExp(`<loc>${url}</loc>`, 'g'))).toHaveLength(1);
		}
	});

	it('publishes localized alternates for each page pair', () => {
		const sitemap = buildSitemap('https://kara.app');

		expect(sitemap).toContain('hreflang="fr" href="https://kara.app/privacy"');
		expect(sitemap).toContain('hreflang="en" href="https://kara.app/en/privacy"');
		expect(sitemap).toContain('hreflang="x-default" href="https://kara.app/privacy"');
	});
});
