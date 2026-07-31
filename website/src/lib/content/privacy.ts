import type { EditorialDocument, EditorialLocale } from './editorial';

export const privacyContent = {
	fr: {
		metaTitle: 'Confidentialité — Kara',
		metaDescription:
			'Comprendre où reste votre inventaire et comment le préremplissage par IA traite temporairement le média que vous choisissez.',
		eyebrow: 'Confidentialité',
		title: 'Vos biens restent vos affaires.',
		intro:
			'Kara gère votre patrimoine physique sans constituer une base d’inventaire en ligne. Cette page distingue votre appareil, votre espace cloud privé, le préremplissage par IA disponible sur option et ce site.',
		updatedLabel: 'Dernière mise à jour',
		updatedDate: '25 juillet 2026',
		updatedDateIso: '2026-07-25',
		skipLinkLabel: 'Aller au contenu',
		contentsLabel: 'Sur cette page',
		backHomeLabel: 'Retour à l’accueil',
		privacyLabel: 'Confidentialité',
		supportLabel: 'Support',
		languageLabel: 'Change language to English',
		alternativeLanguage: 'English',
		footerTagline: 'Votre patrimoine, clairement.',
		legalOperatorLabel: 'Site édité par',
		highlights: ['Aucun compte Kara', 'Inventaire local', 'IA désactivée par défaut'],
		sections: [
			{
				kind: 'text',
				id: 'essentiel',
				title: 'L’essentiel',
				paragraphs: [
					'Vous n’avez pas à créer de compte Kara. Votre inventaire complet reste géré sur votre appareil et, si vous l’utilisez, dans la sauvegarde privée fournie par votre système. Kara ne le stocke pas sur ses serveurs.',
					'Si vous activez le préremplissage par IA, le média que vous choisissez pour une extraction en ligne constitue un flux distinct et limité, détaillé ci-dessous.'
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
						title: 'Pour le préremplissage par IA',
						body: 'Uniquement si vous activez l’option, une photo ou une copie de facture limitée à six pages transite temporairement via Kara vers OpenAI.'
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
					'Ces données constituent votre inventaire complet. Elles restent sur l’appareil et dans votre éventuelle sauvegarde privée ; Kara n’exploite ni compte web ni serveur qui en stocke une copie.',
					'Le préremplissage par IA n’envoie pas votre fiche d’inventaire. Il traite seulement la photo ou la copie d’analyse de facture que vous sélectionnez pour cette opération.'
				]
			},
			{
				kind: 'text',
				id: 'pre-remplissage-ia',
				title: 'Préremplissage assisté par IA',
				paragraphs: [
					'Cette fonction est désactivée par défaut. Si vous l’activez, vous pouvez choisir une photo d’un objet ou une copie d’analyse contenant au maximum six pages sélectionnées d’une facture. Le média transite alors temporairement par le backend Kara vers OpenAI, qui extrait des informations et renvoie des suggestions de champs.',
					'Le backend Kara vérifie et transmet ce média, mais ne le stocke pas. La facture originale et le reste de votre inventaire demeurent sur votre appareil ou dans votre sauvegarde privée.',
					'Pour appliquer les quotas et limiter les abus, Kara crée des pseudonymes HMAC à partir de l’identifiant App Attest de l’installation et de l’adresse IP. Les quotas dits « par installation » sont techniquement appliqués à la clé App Attest. Redis ne conserve pas ces identifiants bruts : il maintient seulement ces pseudonymes et les marqueurs techniques nécessaires aux fenêtres de quota, qui expirent au plus tard après 24 heures. Si le seuil d’abus est atteint, un marqueur de quarantaine associé à cette clé ou à l’adresse IP est conservé pendant sept jours.',
					'Kara conserve ses journaux techniques opérationnels pendant un maximum de 30 jours. Ils comprennent l’identifiant de requête, le type et la taille du média, le nombre de pages le cas échéant, le statut, la latence et le nombre de jetons traités. Ils ne contiennent ni le média, ni les champs extraits, ni l’identifiant App Attest (« keyId »), ni l’adresse IP, ni leurs pseudonymes HMAC.',
					'Pour l’API OpenAI standard utilisée par Kara, les données envoyées ne servent pas à entraîner les modèles d’OpenAI par défaut. OpenAI peut conserver des journaux de surveillance des abus, susceptibles d’inclure ce contenu, pendant un maximum de 30 jours.',
					'Cette fonction nécessite une connexion internet et n’effectue aucune analyse locale sur l’appareil.'
				],
				note:
					'Vous pouvez désactiver cette option à tout moment. L’application cesse alors d’attendre l’analyse en cours et empêche toute nouvelle analyse ; une requête déjà transmise peut toutefois terminer son traitement sans que ses suggestions soient appliquées. Ce traitement sert uniquement au préremplissage des champs de l’application ; il n’est utilisé ni pour le suivi, ni pour la publicité, ni pour le profilage.'
			},
			{
				kind: 'text',
				id: 'sauvegarde',
				title: 'Sauvegarde iCloud et Google Drive',
				paragraphs: [
					'Sur iOS, la sauvegarde s’appuie sur l’espace privé associé au compte iCloud configuré sur l’appareil. Sur Android, elle s’appuie sur l’espace de données applicatives AppData du compte Google Drive configuré sur l’appareil.',
					'Ces espaces sont administrés par Apple ou Google dans le cadre de votre compte et selon leurs propres conditions. Kara ne reçoit pas de copie de votre inventaire complet sur son infrastructure.',
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
					'Pour produire des statistiques agrégées, Umami traite aussi des métadonnées techniques usuelles, notamment l’URL consultée, le site référent, le navigateur, le système d’exploitation, le type d’appareil, la langue et un pays approximatif. Le site n’a pas accès à l’inventaire présent dans l’application et les événements stores ne contiennent aucune donnée patrimoniale.',
					'Cette mesure du site est distincte du préremplissage par IA dans l’application. Les médias choisis pour une extraction ne sont jamais utilisés pour mesurer votre navigation ou suivre votre activité.'
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
					'Vous choisissez d’activer ou non le préremplissage par IA et pouvez revenir sur ce choix à tout moment.',
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
					'L’adresse de contact est momentanément indisponible. Réessayez plus tard.'
			}
		]
	},
	en: {
		metaTitle: 'Privacy — Kara',
		metaDescription:
			'Understand where your inventory stays and how AI-assisted form filling temporarily handles the media you choose.',
		eyebrow: 'Privacy',
		title: 'Your assets remain your business.',
		intro:
			'Kara manages physical wealth without creating an online inventory database. This page distinguishes your device, your private cloud space, optional AI-assisted form filling, and this website.',
		updatedLabel: 'Last updated',
		updatedDate: 'July 25, 2026',
		updatedDateIso: '2026-07-25',
		skipLinkLabel: 'Skip to content',
		contentsLabel: 'On this page',
		backHomeLabel: 'Back to home',
		privacyLabel: 'Privacy',
		supportLabel: 'Support',
		languageLabel: 'Passer le site en français',
		alternativeLanguage: 'Français',
		footerTagline: 'Your wealth, clearly.',
		legalOperatorLabel: 'Website operated by',
		highlights: ['No Kara account', 'Local inventory', 'AI off by default'],
		sections: [
			{
				kind: 'text',
				id: 'essentials',
				title: 'The essentials',
				paragraphs: [
					'You do not need to create a Kara account. Your complete inventory remains managed on your device and, if you use it, in the private backup provided by your operating system. Kara does not store it on its servers.',
					'If you enable AI-assisted form filling, the media you choose for online extraction is a separate and limited data flow, explained below.'
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
						title: 'For AI-assisted form filling',
						body: 'Only when you enable the option, a photo or an invoice copy limited to six pages temporarily passes through Kara to OpenAI.'
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
					'This data makes up your complete inventory. It remains on the device and in your optional private backup; Kara operates neither a web account nor a server that stores a copy of it.',
					'AI-assisted form filling does not send your inventory record. It processes only the photo or invoice analysis copy that you select for that operation.'
				]
			},
			{
				kind: 'text',
				id: 'ai-assisted-form-filling',
				title: 'AI-assisted form filling',
				paragraphs: [
					'This feature is off by default. If you enable it, you can choose an item photo or an analysis copy containing no more than six selected pages of an invoice. The media then passes temporarily through the Kara backend to OpenAI, which extracts information and returns suggested form fields.',
					'The Kara backend validates and forwards this media but does not store it. The original invoice and the rest of your inventory remain on your device or in your private backup.',
					'To enforce quotas and limit abuse, Kara creates HMAC pseudonyms from the installation’s App Attest identifier and IP address. Quotas described as “per installation” are technically applied to the App Attest key. Redis does not retain these raw identifiers: it holds only those pseudonyms and the technical markers needed for quota windows, which expire after no more than 24 hours. If the abuse threshold is reached, a quarantine marker associated with that key or the IP address is retained for seven days.',
					'Kara retains its operational technical logs for no more than 30 days. They include the request ID, media type and size, page count where applicable, status, latency, and token counts. They contain neither the media nor extracted fields, the App Attest “keyId”, the IP address, nor their HMAC pseudonyms.',
					'For the standard OpenAI API used by Kara, submitted data is not used to train OpenAI models by default. OpenAI may retain abuse-monitoring logs, which may include this content, for up to 30 days.',
					'This feature requires an internet connection and performs no local analysis on the device.'
				],
				note:
					'You can turn this option off at any time. The app then stops waiting for an analysis in progress and prevents any new analysis; a request already submitted may still finish processing without its suggestions being applied. This processing is used only to fill in app fields; it is not used for tracking, advertising, or profiling.'
			},
			{
				kind: 'text',
				id: 'backup',
				title: 'iCloud and Google Drive backup',
				paragraphs: [
					'On iOS, backup relies on the private space associated with the iCloud account configured on the device. On Android, it relies on the application data AppData space of the Google Drive account configured on the device.',
					'Apple or Google manages these spaces as part of your account and under its own terms. Kara does not receive a copy of your complete inventory on its infrastructure.',
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
					'To produce aggregate statistics, Umami also processes standard technical metadata, including the page URL, referrer, browser, operating system, device type, language, and an approximate country. The website cannot access the inventory held in the app, and store events contain no wealth or inventory data.',
					'This website measurement is separate from AI-assisted form filling in the app. Media selected for extraction is never used to measure your browsing or track your activity.'
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
					'You choose whether to enable AI-assisted form filling and can change that choice at any time.',
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
					'The contact address is temporarily unavailable. Please try again later.'
			}
		]
	}
} satisfies Record<EditorialLocale, EditorialDocument>;
