import { describe, expect, it } from 'vitest';
import type { EditorialDocument, EditorialLocale } from './editorial';
import { privacyContent } from './privacy';
import { supportContent } from './support';

const documents = [
	['privacy', privacyContent],
	['support', supportContent]
] as const;

describe.each(documents)('%s editorial content', (_name, localizedContent) => {
	it.each(['fr', 'en'] satisfies EditorialLocale[])('%s is complete and internally linked', (locale) => {
		const content: EditorialDocument = localizedContent[locale];
		const sectionIds = content.sections.map(({ id }) => id);

		expect(content.title).not.toHaveLength(0);
		expect(content.metaDescription.length).toBeGreaterThan(80);
		expect(content.highlights).toHaveLength(3);
		expect(new Set(sectionIds).size).toBe(sectionIds.length);
		expect(sectionIds.every((id) => /^[a-z0-9-]+$/.test(id))).toBe(true);
		expect(content.sections.at(-1)?.kind).toBe('contact');
	});

	it('keeps French and English structurally aligned', () => {
		expect(localizedContent.en.sections.map(({ kind }) => kind)).toEqual(
			localizedContent.fr.sections.map(({ kind }) => kind)
		);
	});
});

