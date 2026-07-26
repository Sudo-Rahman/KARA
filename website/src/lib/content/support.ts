import type { EditorialDocument, EditorialLocale } from './editorial';

export const supportContent = {
	fr: {
		metaTitle: 'Support et avant-première — Kara',
		metaDescription:
			'Découvrez le fonctionnement prévu de Kara avant son lancement et contactez-nous sans exposer votre patrimoine.',
		eyebrow: 'Support',
		title: 'Une réponse claire, avant même le lancement.',
		intro:
			'Kara est encore en préparation : aucune application publique n’est disponible aujourd’hui. Ce centre d’aide présente les choix produit validés, sans faire passer une fonction future pour une fonction déjà livrée.',
		updatedLabel: 'Informations mises à jour le',
		updatedDate: '25 juillet 2026',
		updatedDateIso: '2026-07-25',
		skipLinkLabel: 'Aller au contenu',
		contentsLabel: 'Accès rapide',
		backHomeLabel: 'Retour à l’accueil',
		privacyLabel: 'Confidentialité',
		supportLabel: 'Support',
		languageLabel: 'Change language to English',
		alternativeLanguage: 'English',
		footerTagline: 'Votre patrimoine, clairement.',
		legalOperatorLabel: 'Site édité par',
		highlights: ['Pré-lancement transparent', 'Inventaire non stocké par Kara', 'Contact direct'],
		sections: [
			{
				kind: 'text',
				id: 'disponibilite',
				title: 'Kara est en préparation',
				paragraphs: [
					'Les versions iOS et Android ne sont pas encore publiées. Les badges stores de ce site restent désactivés tant qu’aucune fiche officielle n’est disponible.',
					'Au lancement, Kara doit permettre de suivre des lingots, pièces, bijoux et autres métaux précieux physiques, avec leurs quantités, poids, pureté, prix d’achat et lieux de conservation.'
				],
				points: [
					{
						title: 'Plateformes prévues',
						body: 'Une application iOS et une application Android, avec la même promesse de confidentialité.'
					},
					{
						title: 'Accès',
						body: 'Aucun compte Kara : l’application utilisera le compte système déjà configuré sur l’appareil.'
					},
					{
						title: 'Évolution',
						body: 'Les détails d’interface peuvent encore évoluer avant la publication sur les stores.'
					}
				],
				note:
					'Cette page sera mise à jour avec les procédures de diagnostic réelles lorsque des versions publiques auront été testées et publiées.'
			},
			{
				kind: 'faq',
				id: 'confidentialite-prevue',
				title: 'Confidentialité prévue',
				items: [
					{
						question: 'Où mon inventaire sera-t-il conservé ?',
						answer: [
							'Il sera géré sur l’appareil. La sauvegarde privée doit utiliser iCloud sur iOS et l’espace AppData de Google Drive sur Android. Kara ne stockera aucune copie de l’inventaire complet.',
							'Si vous activez le préremplissage par IA, seule la photo ou la copie d’analyse de facture choisie, limitée à six pages, transitera temporairement via Kara vers OpenAI. Le backend Kara ne la stockera pas.'
						]
					},
					{
						question: 'Le préremplissage par IA sera-t-il obligatoire ?',
						answer: [
							'Non. Il sera désactivé par défaut et vous pourrez revenir sur votre choix à tout moment. Son seul objectif sera de proposer des valeurs pour les champs de l’application, sans suivi, publicité ni profilage.',
							'Les données envoyées par l’API OpenAI standard ne servent pas à entraîner ses modèles par défaut. OpenAI pourra toutefois conserver des journaux anti-abus susceptibles d’inclure ce contenu pendant un maximum de 30 jours. Le préremplissage nécessite une connexion internet et n’effectue aucune analyse locale.'
						]
					},
					{
						question: 'Quelles données techniques Kara conservera-t-elle pour une extraction en ligne ?',
						answer: [
							'Pour les quotas, les limites dites « par installation » seront techniquement appliquées à la clé App Attest. Redis conservera seulement des pseudonymes HMAC et des marqueurs de fenêtre pendant au plus 24 heures. Un marqueur de quarantaine associé à cette clé ou à l’adresse IP pourra subsister sept jours si le seuil d’abus est atteint. Le keyId et l’adresse IP ne seront pas conservés sous leur forme brute.',
							'Les journaux opérationnels Kara seront conservés pendant un maximum de 30 jours. Ils pourront contenir l’identifiant de requête, le type et la taille du média, le nombre de pages, le statut, la latence et les jetons traités, mais jamais le média, les champs extraits, le keyId, l’adresse IP ou leurs pseudonymes HMAC.'
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
							'Non. La récupération de cours de référence ne doit joindre ni objets, ni prix d’achat, ni lieux de conservation. Une valeur pourra aussi être ajustée manuellement.'
						]
					}
				]
			},
			{
				kind: 'faq',
				id: 'fonctions-annoncees',
				title: 'Fonctions annoncées',
				items: [
					{
						question: 'Que pourrai-je suivre dans Kara ?',
						answer: [
							'Le produit est prévu pour inventorier des lingots, pièces, bijoux et autres objets en métaux précieux, puis regrouper leur valeur estimée, leur coût d’acquisition, leur répartition et leur plus-value.'
						]
					},
					{
						question: 'Les simulations seront-elles des conseils de vente ?',
						answer: [
							'Non. Les scénarios seront estimatifs, hors frais et fiscalité. Kara ne fournira pas de conseil financier ou fiscal.'
						]
					},
					{
						question: 'Les rapports et PDF seront-ils envoyés à Kara ?',
						answer: [
							'Non. Leur génération est prévue localement sur l’appareil. Si vous choisissez ensuite de partager un PDF, sa destination dépendra de votre action et du service sélectionné.'
						]
					}
				]
			},
			{
				kind: 'text',
				id: 'suivre-lancement',
				title: 'Suivre le lancement',
				paragraphs: [
					'Nous n’ajoutons ni compte d’attente ni formulaire marketing à ce site. Les liens directs seront activés dès que les fiches officielles App Store et Google Play existeront.',
					'Avant cette date, méfiez-vous de tout téléchargement présenté comme une version officielle de Kara en dehors des liens publiés ici.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'Une question avant le lancement ?',
				paragraphs: [
					'Écrivez-nous directement. Votre logiciel de messagerie s’ouvrira : aucun formulaire serveur ne collecte votre demande sur ce site. Pour signaler un problème d’extraction, indiquez seulement l’identifiant de requête si l’application vous en fournit un ; ne joignez ni média, ni champs extraits, ni identifiant App Attest, ni information réelle sur votre patrimoine.'
				],
				emailLabel: 'Écrire au support',
				emailSubject: 'Question avant le lancement de Kara',
				emailUnavailable:
					'L’adresse de support n’est pas encore publiée. Elle sera disponible ici avant le lancement de l’application.'
			}
		]
	},
	en: {
		metaTitle: 'Support and preview — Kara',
		metaDescription:
			'Learn how Kara is intended to work before launch and contact us without exposing your holdings.',
		eyebrow: 'Support',
		title: 'A clear answer, even before launch.',
		intro:
			'Kara is still in development: no public app is available today. This help centre presents validated product decisions without describing a future feature as if it had already shipped.',
		updatedLabel: 'Information updated',
		updatedDate: 'July 25, 2026',
		updatedDateIso: '2026-07-25',
		skipLinkLabel: 'Skip to content',
		contentsLabel: 'Quick access',
		backHomeLabel: 'Back to home',
		privacyLabel: 'Privacy',
		supportLabel: 'Support',
		languageLabel: 'Passer le site en français',
		alternativeLanguage: 'Français',
		footerTagline: 'Your wealth, clearly.',
		legalOperatorLabel: 'Website operated by',
		highlights: ['Transparent preview', 'No inventory stored by Kara', 'Direct contact'],
		sections: [
			{
				kind: 'text',
				id: 'availability',
				title: 'Kara is in development',
				paragraphs: [
					'The iOS and Android apps have not been released yet. This website keeps its store badges disabled until official listings are available.',
					'At launch, Kara is intended to track physical gold bars, coins, jewellery, and other precious-metal assets together with their quantities, weights, purity, purchase prices, and storage locations.'
				],
				points: [
					{
						title: 'Planned platforms',
						body: 'An iOS app and an Android app, both built around the same privacy promise.'
					},
					{
						title: 'Access',
						body: 'No Kara account: the app will use the system account already configured on the device.'
					},
					{
						title: 'Product evolution',
						body: 'Interface details may still change before the store release.'
					}
				],
				note:
					'This page will be updated with real troubleshooting procedures once public builds have been tested and released.'
			},
			{
				kind: 'faq',
				id: 'planned-privacy',
				title: 'Planned privacy model',
				items: [
					{
						question: 'Where will my inventory be stored?',
						answer: [
							'It will be managed on the device. Private backup is intended to use iCloud on iOS and Google Drive AppData on Android. Kara will not store a copy of your complete inventory.',
							'If you enable AI-assisted form filling, only the selected photo or invoice analysis copy, limited to six pages, will temporarily pass through Kara to OpenAI. The Kara backend will not store it.'
						]
					},
					{
						question: 'Will AI-assisted form filling be required?',
						answer: [
							'No. It will be off by default, and you will be able to change your choice at any time. Its sole purpose will be to suggest values for app fields, with no tracking, advertising, or profiling.',
							'Data submitted through the standard OpenAI API is not used to train its models by default. OpenAI may nevertheless keep abuse-monitoring logs, which may include this content, for up to 30 days. Form filling requires an internet connection and performs no local analysis.'
						]
					},
					{
						question: 'What technical data will Kara retain for an online extraction?',
						answer: [
							'For quotas, limits described as “per installation” will technically be applied to the App Attest key. Redis will hold only HMAC pseudonyms and window markers for no more than 24 hours. A quarantine marker associated with that key or the IP address may remain for seven days if the abuse threshold is reached. The keyId and IP address will not be retained in raw form.',
							'Kara operational logs will be retained for no more than 30 days. They may include the request ID, media type and size, page count, status, latency, and token counts, but never the media, extracted fields, keyId, IP address, or their HMAC pseudonyms.'
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
							'No. Reference-price requests are intended to include no items, purchase prices, or storage locations. A value will also be manually adjustable.'
						]
					}
				]
			},
			{
				kind: 'faq',
				id: 'announced-features',
				title: 'Announced features',
				items: [
					{
						question: 'What will I be able to track in Kara?',
						answer: [
							'The product is intended to inventory bars, coins, jewellery, and other precious-metal objects, then consolidate their estimated value, acquisition cost, allocation, and gain.'
						]
					},
					{
						question: 'Will simulations be sale advice?',
						answer: [
							'No. Scenarios will be estimates excluding fees and taxes. Kara will not provide financial or tax advice.'
						]
					},
					{
						question: 'Will reports and PDFs be sent to Kara?',
						answer: [
							'No. They are intended to be generated locally on the device. If you then choose to share a PDF, its destination will depend on your action and the selected service.'
						]
					}
				]
			},
			{
				kind: 'text',
				id: 'follow-launch',
				title: 'Follow the launch',
				paragraphs: [
					'We are not adding a waiting-list account or marketing form to this website. Direct links will be enabled as soon as official App Store and Google Play listings exist.',
					'Until then, be cautious of any download presented as an official Kara release outside the links published here.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'A question before launch?',
				paragraphs: [
					'Email us directly. Your mail app opens without a server form collecting your request on this website. To report an extraction issue, provide only the request ID if the app gives you one; do not attach media, extracted fields, an App Attest identifier, or any real information about your holdings.'
				],
				emailLabel: 'Email support',
				emailSubject: 'Question before Kara launches',
				emailUnavailable:
					'The support address has not been published yet. It will appear here before the app launches.'
			}
		]
	}
} satisfies Record<EditorialLocale, EditorialDocument>;
