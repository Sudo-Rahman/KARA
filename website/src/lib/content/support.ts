import type { EditorialDocument, EditorialLocale } from './editorial';

export const supportContent = {
	fr: {
		metaTitle: 'Support — Kara',
		metaDescription:
			'Consultez le fonctionnement de Kara et contactez le support sans exposer votre patrimoine.',
		eyebrow: 'Support',
		title: 'Une réponse claire, quand vous en avez besoin.',
		intro:
			'Ce centre d’aide présente le fonctionnement de Kara, ses choix de confidentialité et les précautions à prendre pour protéger les informations de votre patrimoine.',
		updatedLabel: 'Informations mises à jour le',
		updatedDate: '30 juillet 2026',
		updatedDateIso: '2026-07-30',
		skipLinkLabel: 'Aller au contenu',
		contentsLabel: 'Accès rapide',
		backHomeLabel: 'Retour à l’accueil',
		privacyLabel: 'Confidentialité',
		supportLabel: 'Support',
		languageLabel: 'Change language to English',
		alternativeLanguage: 'English',
		footerTagline: 'Votre patrimoine, clairement.',
		legalOperatorLabel: 'Site édité par',
		highlights: ['Support pratique', 'Inventaire non stocké par Kara', 'Contact direct'],
		sections: [
			{
				kind: 'text',
				id: 'utilisation',
				title: 'Kara au quotidien',
				paragraphs: [
					'Kara permet de suivre des lingots, pièces, bijoux et autres métaux précieux physiques, avec leurs quantités, poids, pureté, prix d’achat et lieux de conservation.',
					'L’application rassemble l’inventaire, les documents, les valorisations, les simulations de vente et les rapports dans un coffre privé.'
				],
				points: [
					{
						title: 'Plateformes',
						body: 'Kara existe sur iOS et Android, avec la même promesse de confidentialité.'
					},
					{
						title: 'Accès',
						body: 'Aucun compte Kara : l’application utilise le compte système déjà configuré sur l’appareil pour la sauvegarde privée.'
					},
					{
						title: 'Assistance',
						body: 'Le support répond aux questions sur l’utilisation, la confidentialité et les services en ligne de Kara.'
					}
				],
				note:
					'Pour nous aider à diagnostiquer un problème, indiquez la version de Kara, le modèle de l’appareil et la version du système, sans joindre de donnée patrimoniale.'
			},
			{
				kind: 'faq',
				id: 'confidentialite-prevue',
				title: 'Confidentialité',
				items: [
					{
						question: 'Où mon inventaire est-il conservé ?',
						answer: [
							'Il est géré sur l’appareil. La sauvegarde privée utilise iCloud sur iOS et l’espace AppData de Google Drive sur Android. Kara ne stocke aucune copie de l’inventaire complet.',
							'Si vous activez le préremplissage par IA, seule la photo ou la copie d’analyse de facture choisie, limitée à six pages, transite temporairement via Kara vers OpenAI. Le backend Kara ne la stocke pas.'
						]
					},
					{
						question: 'Le préremplissage par IA est-il obligatoire ?',
						answer: [
							'Non. Il est désactivé par défaut et vous pouvez revenir sur votre choix à tout moment. Son seul objectif est de proposer des valeurs pour les champs de l’application, sans suivi, publicité ni profilage.',
							'Les données envoyées par l’API OpenAI standard ne servent pas à entraîner ses modèles par défaut. OpenAI peut toutefois conserver des journaux anti-abus susceptibles d’inclure ce contenu pendant un maximum de 30 jours. Le préremplissage nécessite une connexion internet et n’effectue aucune analyse locale.'
						]
					},
					{
						question: 'Quelles données techniques Kara conserve-t-elle pour une extraction en ligne ?',
						answer: [
							'Pour les quotas, les limites dites « par installation » sont techniquement appliquées à la clé App Attest. Redis conserve seulement des pseudonymes HMAC et des marqueurs de fenêtre pendant au plus 24 heures. Un marqueur de quarantaine associé à cette clé ou à l’adresse IP peut subsister sept jours si le seuil d’abus est atteint. Le keyId et l’adresse IP ne sont pas conservés sous leur forme brute.',
							'Les journaux opérationnels Kara sont conservés pendant un maximum de 30 jours. Ils peuvent contenir l’identifiant de requête, le type et la taille du média, le nombre de pages, le statut, la latence et les jetons traités, mais jamais le média, les champs extraits, le keyId, l’adresse IP ou leurs pseudonymes HMAC.'
						]
					},
					{
						question: 'Faudra-t-il créer un compte Kara ?',
						answer: [
							'Non. Kara est conçue sans compte applicatif. Le compte iCloud ou Google de l’appareil servira uniquement à la sauvegarde privée fournie par le système.'
						]
					},
					{
						question: 'Les cours révéleront-ils le contenu de mon inventaire ?',
						answer: [
							'Non. La récupération de cours de référence ne joint ni objets, ni prix d’achat, ni lieux de conservation. Une valeur peut aussi être ajustée manuellement.'
						]
					}
				]
			},
			{
				kind: 'faq',
				id: 'fonctionnalites',
				title: 'Fonctionnalités',
				items: [
					{
						question: 'Que puis-je suivre dans Kara ?',
						answer: [
							'Kara inventorie des lingots, pièces, bijoux et autres objets en métaux précieux, puis regroupe leur valeur estimée, leur coût d’acquisition, leur répartition et leur plus-value.'
						]
					},
					{
						question: 'Les simulations sont-elles des conseils de vente ?',
						answer: [
							'Non. Les scénarios sont estimatifs, hors frais et fiscalité. Kara ne fournit pas de conseil financier ou fiscal.'
						]
					},
					{
						question: 'Les rapports et PDF sont-ils envoyés à Kara ?',
						answer: [
							'Non. Ils sont générés localement sur l’appareil. Si vous choisissez ensuite de partager un PDF, sa destination dépend de votre action et du service sélectionné.'
						]
					}
				]
			},
			{
				kind: 'text',
				id: 'telechargements',
				title: 'Téléchargements officiels',
				paragraphs: [
					'Kara ne propose ni compte d’attente ni formulaire marketing sur ce site.',
					'Utilisez uniquement les liens App Store et Google Play affichés sur le site officiel. N’installez aucune version présentée comme officielle depuis une autre source.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'Besoin d’aide ?',
				paragraphs: [
					'Écrivez-nous directement. Votre logiciel de messagerie s’ouvrira : aucun formulaire serveur ne collecte votre demande sur ce site. Pour signaler un problème d’extraction, indiquez seulement l’identifiant de requête si l’application vous en fournit un ; ne joignez ni média, ni champs extraits, ni identifiant App Attest, ni information réelle sur votre patrimoine.'
				],
				emailLabel: 'Écrire au support',
				emailSubject: 'Support Kara',
				emailUnavailable:
					'L’adresse de support est momentanément indisponible. Réessayez plus tard.'
			}
		]
	},
	en: {
		metaTitle: 'Support — Kara',
		metaDescription:
			'Learn how Kara works, review its privacy safeguards, and contact support without exposing your holdings.',
		eyebrow: 'Support',
		title: 'A clear answer, when you need it.',
		intro:
			'This help centre explains how Kara works, its privacy choices, and the precautions to take when protecting information about your holdings.',
		updatedLabel: 'Information updated',
		updatedDate: 'July 30, 2026',
		updatedDateIso: '2026-07-30',
		skipLinkLabel: 'Skip to content',
		contentsLabel: 'Quick access',
		backHomeLabel: 'Back to home',
		privacyLabel: 'Privacy',
		supportLabel: 'Support',
		languageLabel: 'Passer le site en français',
		alternativeLanguage: 'Français',
		footerTagline: 'Your wealth, clearly.',
		legalOperatorLabel: 'Website operated by',
		highlights: ['Practical support', 'No inventory stored by Kara', 'Direct contact'],
		sections: [
			{
				kind: 'text',
				id: 'everyday-use',
				title: 'Using Kara every day',
				paragraphs: [
					'Kara tracks physical gold bars, coins, jewellery, and other precious-metal assets together with their quantities, weights, purity, purchase prices, and storage locations.',
					'The app brings inventory, documents, valuations, sale simulations, and reports together in one private vault.'
				],
				points: [
					{
						title: 'Platforms',
						body: 'Kara is available for iOS and Android, both built around the same privacy promise.'
					},
					{
						title: 'Access',
						body: 'No Kara account: the app uses the system account already configured on the device for private backup.'
					},
					{
						title: 'Assistance',
						body: 'Support answers questions about using Kara, privacy, and its online services.'
					}
				],
				note:
					'To help us diagnose an issue, provide the Kara version, device model, and operating-system version without attaching any holdings data.'
			},
			{
				kind: 'faq',
				id: 'privacy',
				title: 'Privacy',
				items: [
					{
						question: 'Where is my inventory stored?',
						answer: [
							'It is managed on the device. Private backup uses iCloud on iOS and Google Drive AppData on Android. Kara does not store a copy of your complete inventory.',
							'If you enable AI-assisted form filling, only the selected photo or invoice analysis copy, limited to six pages, temporarily passes through Kara to OpenAI. The Kara backend does not store it.'
						]
					},
					{
						question: 'Is AI-assisted form filling required?',
						answer: [
							'No. It is off by default, and you can change your choice at any time. Its sole purpose is to suggest values for app fields, with no tracking, advertising, or profiling.',
							'Data submitted through the standard OpenAI API is not used to train its models by default. OpenAI may nevertheless keep abuse-monitoring logs, which may include this content, for up to 30 days. Form filling requires an internet connection and performs no local analysis.'
						]
					},
					{
						question: 'What technical data does Kara retain for an online extraction?',
						answer: [
							'For quotas, limits described as “per installation” may technically be applied to the App Attest key. Redis holds only HMAC pseudonyms and window markers for no more than 24 hours. A quarantine marker associated with that key or the IP address may remain for seven days if the abuse threshold is reached. The keyId and IP address are not retained in raw form.',
							'Kara operational logs are retained for no more than 30 days. They may include the request ID, media type and size, page count, status, latency, and token counts, but never the media, extracted fields, keyId, IP address, or their HMAC pseudonyms.'
						]
					},
					{
						question: 'Will I need a Kara account?',
						answer: [
							'No. Kara is designed without an app-specific account. The device’s iCloud or Google account will only support the private backup provided by the operating system.'
						]
					},
					{
						question: 'Will market-price requests reveal my inventory?',
						answer: [
							'No. Reference-price requests include no items, purchase prices, or storage locations. A value can also be adjusted manually.'
						]
					}
				]
			},
			{
				kind: 'faq',
				id: 'features',
				title: 'Features',
				items: [
					{
						question: 'What can I track in Kara?',
						answer: [
							'Kara inventories bars, coins, jewellery, and other precious-metal objects, then consolidates their estimated value, acquisition cost, allocation, and gain.'
						]
					},
					{
						question: 'Are simulations sale advice?',
						answer: [
							'No. Scenarios are estimates excluding fees and taxes. Kara does not provide financial or tax advice.'
						]
					},
					{
						question: 'Are reports and PDFs sent to Kara?',
						answer: [
							'No. They are generated locally on the device. If you then choose to share a PDF, its destination depends on your action and the selected service.'
						]
					}
				]
			},
			{
				kind: 'text',
				id: 'downloads',
				title: 'Official downloads',
				paragraphs: [
					'Kara does not offer a waiting-list account or marketing form on this website.',
					'Use only the App Store and Google Play links displayed on the official website. Do not install any version presented as official from another source.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'Need help?',
				paragraphs: [
					'Email us directly. Your mail app opens without a server form collecting your request on this website. To report an extraction issue, provide only the request ID if the app gives you one; do not attach media, extracted fields, an App Attest identifier, or any real information about your holdings.'
				],
				emailLabel: 'Email support',
				emailSubject: 'Kara support',
				emailUnavailable:
					'The support address is temporarily unavailable. Please try again later.'
			}
		]
	}
} satisfies Record<EditorialLocale, EditorialDocument>;
