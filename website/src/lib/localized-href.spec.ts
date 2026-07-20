import { describe, expect, it } from 'vitest';
import { normalizeLocalizedHref } from './localized-href';

describe('normalizeLocalizedHref', () => {
	it('removes the redirecting slash from the English root and its anchors', () => {
		expect(normalizeLocalizedHref('/en/')).toBe('/en');
		expect(normalizeLocalizedHref('/en/#inventory')).toBe('/en#inventory');
	});

	it('leaves nested and French routes unchanged', () => {
		expect(normalizeLocalizedHref('/en/privacy')).toBe('/en/privacy');
		expect(normalizeLocalizedHref('/#download')).toBe('/#download');
	});
});
