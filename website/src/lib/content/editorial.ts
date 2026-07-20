export type EditorialLocale = 'fr' | 'en';

export type EditorialPoint = {
	title: string;
	body: string;
};

export type EditorialTextSection = {
	kind: 'text';
	id: string;
	title: string;
	intro?: string;
	paragraphs?: string[];
	points?: EditorialPoint[];
	bullets?: string[];
	note?: string;
};

export type EditorialFaqSection = {
	kind: 'faq';
	id: string;
	title: string;
	intro?: string;
	items: Array<{
		question: string;
		answer: string[];
	}>;
};

export type EditorialContactSection = {
	kind: 'contact';
	id: string;
	title: string;
	paragraphs: string[];
	emailLabel: string;
	emailSubject: string;
	emailUnavailable: string;
};

export type EditorialSection =
	| EditorialTextSection
	| EditorialFaqSection
	| EditorialContactSection;

export type EditorialDocument = {
	metaTitle: string;
	metaDescription: string;
	eyebrow: string;
	title: string;
	intro: string;
	updatedLabel: string;
	updatedDate: string;
	updatedDateIso: string;
	skipLinkLabel: string;
	contentsLabel: string;
	backHomeLabel: string;
	privacyLabel: string;
	supportLabel: string;
	languageLabel: string;
	alternativeLanguage: string;
	footerTagline: string;
	legalOperatorLabel: string;
	highlights: string[];
	sections: EditorialSection[];
};
