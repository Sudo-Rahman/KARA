const localizedPages = [
	{ fr: '/', en: '/en' },
	{ fr: '/privacy', en: '/en/privacy' },
	{ fr: '/support', en: '/en/support' }
] as const;

function escapeXml(value: string): string {
	return value
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;')
		.replaceAll("'", '&apos;');
}

function joinUrl(baseUrl: string, path: string): string {
	const relativePath = path === '/' ? '' : path.replace(/^\//, '');
	return new URL(relativePath, `${baseUrl.replace(/\/$/, '')}/`).href.replace(
		/\/$/,
		path === '/' ? '/' : ''
	);
}

export const sitemapPaths = localizedPages.flatMap(({ fr, en }) => [fr, en]);

export function buildSitemap(baseUrl: string): string {
	const entries = localizedPages.flatMap(({ fr, en }) => {
		const alternates = [
			{ locale: 'fr', path: fr },
			{ locale: 'en', path: en },
			{ locale: 'x-default', path: fr }
		]
			.map(
				({ locale, path }) =>
					`    <xhtml:link rel="alternate" hreflang="${locale}" href="${escapeXml(joinUrl(baseUrl, path))}" />`
			)
			.join('\n');

		return [fr, en].map(
			(path) =>
				`  <url>\n    <loc>${escapeXml(joinUrl(baseUrl, path))}</loc>\n${alternates}\n  </url>`
		);
	});

	return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${entries.join('\n')}\n</urlset>\n`;
}
