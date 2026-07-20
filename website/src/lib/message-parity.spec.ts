import { describe, expect, it } from 'vitest';
import english from '../../messages/en.json';
import french from '../../messages/fr.json';

describe('Paraglide message catalogues', () => {
	it('keeps the French and English key sets in exact parity', () => {
		expect(Object.keys(english).sort()).toEqual(Object.keys(french).sort());
	});

	it('does not ship empty translations', () => {
		for (const [locale, messages] of [
			['fr', french],
			['en', english]
		] as const) {
			for (const [key, value] of Object.entries(messages)) {
				expect(value, `${locale}.${key}`).not.toBe('');
			}
		}
	});
});
