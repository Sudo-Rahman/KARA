import type { EditorialDocument, EditorialLocale } from './editorial';

export const privacyContent = {
	fr: {
		metaTitle: 'Confidentialité — Kara',
		metaDescription:
			'Comprendre précisément où Kara conserve votre inventaire, comment les cours sont récupérés et ce que mesure le site.',
		eyebrow: 'Confidentialité',
		title: 'Vos biens restent vos affaires.',
		intro:
			'Kara n’est pas encore publiée. Elle est conçue pour gérer un patrimoine physique sans constituer une nouvelle base de données en ligne. Cette page décrit le fonctionnement prévu de l’application et distingue clairement votre appareil, votre espace cloud privé et ce site.',
		updatedLabel: 'Dernière mise à jour',
		updatedDate: '20 juillet 2026',
		updatedDateIso: '2026-07-20',
		skipLinkLabel: 'Aller au contenu',
		contentsLabel: 'Sur cette page',
		backHomeLabel: 'Retour à l’accueil',
		privacyLabel: 'Confidentialité',
		supportLabel: 'Support',
		languageLabel: 'Change language to English',
		alternativeLanguage: 'English',
		footerTagline: 'Votre patrimoine, clairement.',
		legalOperatorLabel: 'Site édité par',
		highlights: ['Aucun compte Kara', 'Inventaire local', 'Mesure du site sans cookie'],
		sections: [
			{
				kind: 'text',
				id: 'essentiel',
				title: 'L’essentiel',
				paragraphs: [
					'Vous n’avez pas à créer de compte Kara. L’inventaire que vous saisissez dans l’application n’est pas envoyé vers un serveur exploité par Kara.',
					'L’application, la sauvegarde fournie par votre système, les cours de référence et ce site correspondent à des flux distincts. Ils sont détaillés ci-dessous.'
				],
				points: [
					{
						title: 'Dans l’application',
						body: 'Vos objets, valeurs, lieux de conservation et calculs restent gérés sur votre appareil.'
					},
					{
						title: 'Dans votre cloud privé',
						body: 'La sauvegarde utilise l’espace lié à votre compte iCloud sur iOS ou l’espace AppData de Google Drive sur Android.'
					},
					{
						title: 'Sur kara.app',
						body: 'Une mesure d’audience sans cookie compte les pages vues et les clics vers les stores, avec les métadonnées techniques décrites plus bas.'
					}
				]
			},
			{
				kind: 'text',
				id: 'donnees-application',
				title: 'Les données de l’application',
				intro:
					'Kara traite les informations nécessaires pour rendre votre patrimoine lisible et calculer son évolution.',
				bullets: [
					'Les caractéristiques des lingots, pièces, bijoux et autres objets que vous enregistrez.',
					'Les quantités, poids, prix et dates d’achat que vous renseignez.',
					'Les lieux de conservation et notes que vous choisissez d’ajouter.',
					'Les valorisations, plus-values estimées et scénarios de vente calculés à partir de ces informations.'
				],
				paragraphs: [
					'Ces données sont conservées sur l’appareil. Kara n’exploite pas de compte web ni de serveur d’inventaire auquel elles seraient transmises.'
				]
			},
			{
				kind: 'text',
				id: 'sauvegarde',
				title: 'Sauvegarde iCloud et Google Drive',
				paragraphs: [
					'Sur iOS, la sauvegarde s’appuie sur l’espace privé associé au compte iCloud configuré sur l’appareil. Sur Android, elle s’appuie sur l’espace de données applicatives AppData du compte Google Drive configuré sur l’appareil.',
					'Ces espaces sont administrés par Apple ou Google dans le cadre de votre compte et selon leurs propres conditions. Kara ne reçoit pas de copie de votre inventaire sur son infrastructure.',
					'La disponibilité d’une sauvegarde dépend notamment de la connexion au bon compte, des réglages du système, de la connexion réseau et de l’espace disponible.'
				],
				note:
					'Avant de changer d’appareil ou de désinstaller l’application, vérifiez que le compte cloud attendu est actif et que la synchronisation a pu se terminer.'
			},
			{
				kind: 'text',
				id: 'cours',
				title: 'Cours de référence',
				paragraphs: [
					'L’application peut récupérer des cours de référence pour les métaux précieux. Cette requête ne contient pas votre inventaire, vos prix d’achat, vos lieux de conservation ni vos simulations.',
					'Comme pour toute connexion à un service en ligne, le fournisseur du cours et les intermédiaires réseau peuvent recevoir les informations techniques nécessaires à la communication. Vous pouvez ajuster manuellement les valeurs utilisées par Kara.'
				]
			},
			{
				kind: 'text',
				id: 'rapports',
				title: 'Rapports et PDF',
				paragraphs: [
					'Les rapports interactifs et les PDF sont générés localement sur votre appareil à partir de vos données. Kara ne reçoit pas leur contenu.',
					'Si vous exportez ou partagez un PDF, vous choisissez sa destination. Le fichier quitte alors l’application selon l’action que vous avez demandée et les règles du service destinataire.'
				],
				note:
					'Un rapport peut contenir des informations sensibles. Vérifiez son contenu et son destinataire avant de le partager.'
			},
			{
				kind: 'text',
				id: 'mesure-site',
				title: 'Mesure minimale de ce site',
				paragraphs: [
					'Le site utilise Umami sans cookie pour mesurer les pages vues et deux clics personnalisés : départ vers l’App Store ou vers Google Play. Aucun rejeu de session, aucune carte de chaleur et aucun formulaire marketing ne sont utilisés. Le traceur respecte le signal « Ne pas me pister » du navigateur et exclut les paramètres de recherche des URL mesurées.',
					'Pour produire des statistiques agrégées, Umami traite aussi des métadonnées techniques usuelles, notamment l’URL consultée, le site référent, le navigateur, le système d’exploitation, le type d’appareil, la langue et un pays approximatif. Le site n’a pas accès à l’inventaire présent dans l’application et les événements stores ne contiennent aucune donnée patrimoniale.'
				],
				points: [
					{
						title: 'Pages vues',
						body: 'Une mesure agrégée nous aide à comprendre quelles pages sont consultées.'
					},
					{
						title: 'Clics stores',
						body: 'Deux événements distinguent les départs vers l’App Store et vers Google Play.'
					}
				]
			},
			{
				kind: 'text',
				id: 'services-externes',
				title: 'Liens et services externes',
				paragraphs: [
					'Lorsque vous suivez un lien vers l’App Store ou Google Play, vous quittez ce site. Apple ou Google traite alors votre visite selon sa propre politique de confidentialité.',
					'De même, le lien de contact ouvre votre logiciel de messagerie. Le contenu que vous envoyez est traité par votre fournisseur de messagerie et par le service de support afin de répondre à votre demande.'
				]
			},
			{
				kind: 'text',
				id: 'vos-choix',
				title: 'Vos choix',
				bullets: [
					'Vous décidez quelles informations enregistrer dans Kara.',
					'Vous pouvez ajuster manuellement les valeurs de référence utilisées dans vos calculs.',
					'Vous choisissez quand créer, exporter ou partager un rapport.',
					'Vous gérez le compte cloud et les réglages de sauvegarde depuis votre appareil.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'Une question sur vos données ?',
				paragraphs: [
					'Expliquez-nous votre question sans joindre votre inventaire, vos lieux de conservation, vos identifiants cloud ni un rapport patrimonial complet.'
				],
				emailLabel: 'Contacter Kara',
				emailSubject: 'Question sur la confidentialité de Kara',
				emailUnavailable:
					'L’adresse de contact n’est pas encore publiée. Elle sera disponible ici avant le lancement de l’application.'
			}
		]
	},
	en: {
		metaTitle: 'Privacy — Kara',
		metaDescription:
			'Understand exactly where Kara keeps your inventory, how market prices are retrieved, and what the website measures.',
		eyebrow: 'Privacy',
		title: 'Your assets remain your business.',
		intro:
			'Kara has not been released yet. It is designed to manage physical wealth without creating another online database. This page describes the app’s intended operation and clearly separates your device, your private cloud space, and this website.',
		updatedLabel: 'Last updated',
		updatedDate: 'July 20, 2026',
		updatedDateIso: '2026-07-20',
		skipLinkLabel: 'Skip to content',
		contentsLabel: 'On this page',
		backHomeLabel: 'Back to home',
		privacyLabel: 'Privacy',
		supportLabel: 'Support',
		languageLabel: 'Passer le site en français',
		alternativeLanguage: 'Français',
		footerTagline: 'Your wealth, clearly.',
		legalOperatorLabel: 'Website operated by',
		highlights: ['No Kara account', 'Local inventory', 'Cookie-free site measurement'],
		sections: [
			{
				kind: 'text',
				id: 'essentials',
				title: 'The essentials',
				paragraphs: [
					'You do not need to create a Kara account. The inventory you enter in the app is not sent to a server operated by Kara.',
					'The app, the backup provided by your operating system, market prices, and this website are separate data flows. Each is explained below.'
				],
				points: [
					{
						title: 'In the app',
						body: 'Your items, values, storage locations, and calculations remain managed on your device.'
					},
					{
						title: 'In your private cloud',
						body: 'Backup uses the space tied to your iCloud account on iOS or the Google Drive AppData space on Android.'
					},
					{
						title: 'On kara.app',
						body: 'Cookie-free analytics count page views and store clicks along with the technical metadata described below.'
					}
				]
			},
			{
				kind: 'text',
				id: 'app-data',
				title: 'Data in the app',
				intro:
					'Kara processes the information needed to make your physical wealth understandable and calculate how it changes.',
				bullets: [
					'Details about the bars, coins, jewellery, and other items you record.',
					'The quantities, weights, purchase prices, and dates you enter.',
					'The storage locations and notes you choose to add.',
					'Valuations, estimated gains, and sale scenarios calculated from this information.'
				],
				paragraphs: [
					'This data is kept on the device. Kara does not operate a web account or inventory server to which it is sent.'
				]
			},
			{
				kind: 'text',
				id: 'backup',
				title: 'iCloud and Google Drive backup',
				paragraphs: [
					'On iOS, backup relies on the private space associated with the iCloud account configured on the device. On Android, it relies on the application data AppData space of the Google Drive account configured on the device.',
					'Apple or Google manages these spaces as part of your account and under its own terms. Kara does not receive a copy of your inventory on its infrastructure.',
					'Backup availability depends on factors such as being signed in to the correct account, system settings, network access, and available storage.'
				],
				note:
					'Before changing devices or uninstalling the app, confirm that the expected cloud account is active and that syncing has had time to finish.'
			},
			{
				kind: 'text',
				id: 'market-prices',
				title: 'Reference market prices',
				paragraphs: [
					'The app may retrieve reference prices for precious metals. That request does not include your inventory, purchase prices, storage locations, or simulations.',
					'As with any connection to an online service, the price provider and network intermediaries may receive the technical information needed for that communication. You can manually adjust the values Kara uses.'
				]
			},
			{
				kind: 'text',
				id: 'reports',
				title: 'Reports and PDFs',
				paragraphs: [
					'Interactive reports and PDFs are generated locally on your device from your data. Kara does not receive their contents.',
					'If you export or share a PDF, you choose its destination. The file then leaves the app as a result of the action you requested and under the destination service’s rules.'
				],
				note:
					'A report may contain sensitive information. Check its contents and recipient before sharing it.'
			},
			{
				kind: 'text',
				id: 'site-measurement',
				title: 'Minimal website measurement',
				paragraphs: [
					'This website uses cookie-free Umami analytics to measure page views and two custom clicks: outbound visits to the App Store or Google Play. It uses no session replay, heatmaps, or marketing forms. The tracker respects the browser’s Do Not Track signal and excludes search parameters from measured URLs.',
					'To produce aggregate statistics, Umami also processes standard technical metadata, including the page URL, referrer, browser, operating system, device type, language, and an approximate country. The website cannot access the inventory held in the app, and store events contain no wealth or inventory data.'
				],
				points: [
					{
						title: 'Page views',
						body: 'Aggregate measurement helps us understand which pages are visited.'
					},
					{
						title: 'Store clicks',
						body: 'Two events distinguish outbound visits to the App Store and Google Play.'
					}
				]
			},
			{
				kind: 'text',
				id: 'external-services',
				title: 'External links and services',
				paragraphs: [
					'When you follow a link to the App Store or Google Play, you leave this website. Apple or Google then processes your visit under its own privacy policy.',
					'Likewise, the contact link opens your email software. What you send is handled by your email provider and by the support service in order to answer your request.'
				]
			},
			{
				kind: 'text',
				id: 'your-choices',
				title: 'Your choices',
				bullets: [
					'You decide what information to record in Kara.',
					'You can manually adjust the reference values used in your calculations.',
					'You choose when to create, export, or share a report.',
					'You manage your cloud account and backup settings from your device.'
				]
			},
			{
				kind: 'contact',
				id: 'contact',
				title: 'A question about your data?',
				paragraphs: [
					'Tell us what you need without attaching your inventory, storage locations, cloud credentials, or a complete wealth report.'
				],
				emailLabel: 'Contact Kara',
				emailSubject: 'Question about Kara privacy',
				emailUnavailable:
					'The contact address has not been published yet. It will appear here before the app launches.'
			}
		]
	}
} satisfies Record<EditorialLocale, EditorialDocument>;
