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

describe('AI-assisted form filling privacy disclosures', () => {
	it.each([
		[
			'fr',
			[
				'désactivée par défaut',
				'au maximum six pages',
				'ne le stocke pas',
				'ne servent pas à entraîner',
				'maximum de 30 jours',
				'ni pour le suivi'
			]
		],
		[
			'en',
			[
				'off by default',
				'no more than six selected pages',
				'does not store it',
				'not used to train',
				'up to 30 days',
				'not used for tracking'
			]
		]
	] satisfies Array<[EditorialLocale, string[]]>)('%s states every material safeguard', (locale, safeguards) => {
		const policy = JSON.stringify(privacyContent[locale]);

		for (const safeguard of safeguards) {
			expect(policy).toContain(safeguard);
		}
	});

	it.each([
		[
			'fr',
			[
				'pseudonymes HMAC',
				'techniquement appliqués à la clé App Attest',
				'au plus tard après 24 heures',
				'pendant sept jours',
				'associé à cette clé ou à l’adresse IP',
				'journaux techniques opérationnels pendant un maximum de 30 jours',
				'l’identifiant de requête',
				'le nombre de pages',
				'la latence',
				'le nombre de jetons',
				'ni le média',
				'ni les champs extraits',
				'Redis ne conserve pas ces identifiants bruts',
				'ni leurs pseudonymes HMAC'
			]
		],
		[
			'en',
			[
				'HMAC pseudonyms',
				'technically applied to the App Attest key',
				'after no more than 24 hours',
				'for seven days',
				'associated with that key or the IP address',
				'operational technical logs for no more than 30 days',
				'the request ID',
				'page count',
				'latency',
				'token counts',
				'neither the media nor extracted fields',
				'does not retain these raw identifiers',
				'nor their HMAC pseudonyms'
			]
		]
	] satisfies Array<[EditorialLocale, string[]]>)('%s details Kara quota and log retention', (locale, disclosures) => {
		const policy = JSON.stringify(privacyContent[locale]);

		for (const disclosure of disclosures) {
			expect(policy).toContain(disclosure);
		}
	});
});

describe('AI extraction support guidance', () => {
	it.each([
		[
			'fr',
			[
				'seulement des pseudonymes HMAC',
				'techniquement appliquées à la clé App Attest',
				'pendant au plus 24 heures',
				'sept jours',
				'associé à cette clé ou à l’adresse IP',
				'maximum de 30 jours',
				'mais jamais le média',
				'keyId, l’adresse IP ou leurs pseudonymes HMAC',
				'indiquez seulement l’identifiant de requête'
			]
		],
		[
			'en',
			[
				'only HMAC pseudonyms',
				'technically be applied to the App Attest key',
				'for no more than 24 hours',
				'seven days',
				'associated with that key or the IP address',
				'for no more than 30 days',
				'but never the media',
				'keyId, IP address, or their HMAC pseudonyms',
				'provide only the request ID'
			]
		]
	] satisfies Array<[EditorialLocale, string[]]>)('%s gives retention and safe diagnostic instructions', (locale, guidance) => {
		const support = JSON.stringify(supportContent[locale]);

		for (const item of guidance) {
			expect(support).toContain(item);
		}
	});
});
