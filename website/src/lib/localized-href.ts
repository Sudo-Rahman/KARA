/** Keeps localized root URLs aligned with the canonical `/en` route. */
export function normalizeLocalizedHref(href: string): string {
	return href.replace(/^\/en\/(?=#|$)/, '/en');
}
