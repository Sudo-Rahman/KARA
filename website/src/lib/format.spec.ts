import { describe, expect, it } from 'vitest';
import { formatCurrency, formatNumber, formatPercent, formatReportDate } from './format';

describe('localized display formatters', () => {
	it('formats euro values for French and English readers', () => {
		expect(formatCurrency(15_920, 'fr')).toMatch(/^15[\s\u00a0\u202f]920[\s\u00a0\u202f]€$/);
		expect(formatCurrency(15_920, 'en')).toBe('€15,920');
	});

	it('formats decimal numbers and percentages by locale', () => {
		expect(formatNumber(999.9, 'fr', 1)).toBe('999,9');
		expect(formatNumber(999.9, 'en', 1)).toBe('999.9');
		expect(formatPercent(0.1828, 'fr', 2)).toMatch(/^18,28[\s\u00a0\u202f]%$/);
		expect(formatPercent(0.1828, 'en', 2)).toBe('18.28%');
	});

	it('localizes the sample report date', () => {
		expect(formatReportDate('fr')).toMatch(/20.*juil.*2026/i);
		expect(formatReportDate('en')).toMatch(/20.*Jul.*2026/i);
	});
});
