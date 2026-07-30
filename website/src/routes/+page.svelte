<script lang="ts">
	import { onMount } from 'svelte';
	import AppleIcon from '@lucide/svelte/icons/apple';
	import ArrowDownIcon from '@lucide/svelte/icons/arrow-down';
	import ArrowRightIcon from '@lucide/svelte/icons/arrow-right';
	import CloudIcon from '@lucide/svelte/icons/cloud';
	import EyeIcon from '@lucide/svelte/icons/eye';
	import EyeOffIcon from '@lucide/svelte/icons/eye-off';
	import FileTextIcon from '@lucide/svelte/icons/file-text';
	import LockKeyholeIcon from '@lucide/svelte/icons/lock-keyhole';
	import ShieldCheckIcon from '@lucide/svelte/icons/shield-check';
	import SiteHeader from '$lib/components/SiteHeader.svelte';
	import DeviceFrame from '$lib/components/landing/DeviceFrame.svelte';
	import VaultAperture from '$lib/components/landing/VaultAperture.svelte';
	import { publicConfig } from '$lib/config';
	import { getLocale } from '$lib/paraglide/runtime';

	type ShowcaseItem = {
		title: string;
		body: string;
		note: string;
		screen: string;
		alt: string;
	};

	type LandingCopy = {
		metaTitle: string;
		metaDescription: string;
		navExperience: string;
		navPrivacy: string;
		appStore: string;
		heroKicker: string;
		heroLineOne: string;
		heroLineTwo: string;
		heroBody: string;
		heroProof: string;
		explore: string;
		scroll: string;
		metalsLabel: string;
		metals: string[];
		manifestoTitle: string;
		manifestoBody: string;
		manifestoCaption: string;
		manifestoScreen: string;
		manifestoScreenAlt: string;
		showcaseTitle: string;
		showcaseBody: string;
		showcase: ShowcaseItem[];
		journeyTitle: string;
		journeyBody: string;
		journey: { title: string; body: string }[];
		privacyTitle: string;
		privacyBody: string;
		estimatedValue: string;
		showValues: string;
		hideValues: string;
		hiddenValue: string;
		visibleValue: string;
		valueHint: string;
		privacyProofs: { title: string; body: string }[];
		phoneNode: string;
		icloudNode: string;
		serverNode: string;
		serverNodeBody: string;
		privacyLink: string;
		finalTitle: string;
		finalBody: string;
		support: string;
		privacy: string;
		legal: string;
		heroScreen: string;
		heroScreenAlt: string;
		privacyScreen: string;
		privacyScreenAlt: string;
	};

	const copyByLocale = {
		fr: {
			metaTitle: 'KARA — Coffre patrimonial privé pour vos métaux précieux',
			metaDescription:
				'Inventoriez vos lingots, pièces et bijoux, suivez leur valeur et préparez vos décisions dans un coffre privé synchronisé par iCloud.',
			navExperience: 'Expérience',
			navPrivacy: 'Confidentialité',
			appStore: 'Télécharger',
			heroKicker: 'Coffre patrimonial privé',
			heroLineOne: 'Votre patrimoine.',
			heroLineTwo: 'Sous contrôle.',
			heroBody:
				'Inventoriez vos métaux précieux, suivez leur valeur et préparez vos décisions dans un coffre privé.',
			heroProof: 'Sans compte Kara. Synchronisé par iCloud.',
			explore: 'Voir l’expérience',
			scroll: 'Ouvrir le coffre',
			metalsLabel: 'Kara suit vos métaux précieux physiques',
			metals: ['Lingots', 'Pièces', 'Bijoux', 'Or', 'Argent', 'Platine', 'Palladium'],
			manifestoTitle: 'Un coffre numérique pour ce qui est bien réel.',
			manifestoBody:
				'Kara relie chaque objet à ce qui compte : son poids, sa pureté, son coût, ses documents et sa valeur métal. Pas un portefeuille abstrait. Votre patrimoine physique, enfin lisible.',
			manifestoCaption: 'Chaque gramme conserve son histoire.',
			manifestoScreen: '/landing/screens/fr/03-detail-actif.webp',
			manifestoScreenAlt: 'Fiche détaillée d’un actif physique dans Kara',
			showcaseTitle: 'Tout est là. Rien n’est noyé.',
			showcaseBody:
				'Une interface conçue pour comprendre votre coffre en quelques secondes, puis aller aussi loin que vous le souhaitez.',
			showcase: [
				{
					title: 'Chaque actif, parfaitement classé.',
					body:
						'Lingots, pièces, bijoux et actifs personnalisés restent faciles à retrouver, même quand le coffre grandit.',
					note: 'Recherche · filtres · tags',
					screen: '/landing/screens/fr/02-inventaire.webp',
					alt: 'Inventaire de métaux précieux dans Kara'
				},
				{
					title: 'Voyez ce qui fait évoluer votre coffre.',
					body:
						'Valeur actuelle, coût d’acquisition et plus-value latente sont présentés avec le contexte qui évite les faux raccourcis.',
					note: 'Or · argent · platine · palladium',
					screen: '/landing/screens/fr/04-performance.webp',
					alt: 'Analyse de performance du coffre Kara'
				},
				{
					title: 'Testez une vente. Ne touchez à rien.',
					body:
						'Ajustez une sélection et ses quantités, puis comparez produit estimé, coût proratisé et gain potentiel.',
					note: 'Simulation sans impact sur l’inventaire',
					screen: '/landing/screens/fr/06-objectifs-et-ventes.webp',
					alt: 'Objectifs de prix et ventes dans Kara'
				},
				{
					title: 'Vos preuves restent avec vos actifs.',
					body:
						'Photos, factures et certificats accompagnent chaque fiche. Un rapport PDF complet est généré localement quand vous le décidez.',
					note: 'Documents réunis · rapport local',
					screen: '/landing/screens/fr/07-documents.webp',
					alt: 'Documents associés à un actif dans Kara'
				}
			],
			journeyTitle: 'Comprendre avant de décider.',
			journeyBody:
				'Kara ne vous pousse pas à agir. L’app vous donne une lecture calme et complète de ce que vous détenez.',
			journey: [
				{
					title: 'Inventorier',
					body: 'Décrire précisément chaque objet et son origine.'
				},
				{
					title: 'Valoriser',
					body: 'Estimer sa valeur métal à partir des cours disponibles.'
				},
				{
					title: 'Simuler',
					body: 'Explorer un scénario sans modifier le coffre.'
				},
				{
					title: 'Décider',
					body: 'Agir avec votre propre contexte, au bon moment.'
				}
			],
			privacyTitle: 'Votre inventaire ne vit pas chez nous.',
			privacyBody:
				'Il reste sur votre iPhone et dans votre base iCloud privée. Face ID protège l’accès, les montants peuvent disparaître d’un geste et Kara ne vous demande aucun compte.',
			estimatedValue: 'Valeur estimée',
			showValues: 'Afficher les montants',
			hideValues: 'Masquer les montants',
			hiddenValue: '••••• €',
			visibleValue: '17 569 €',
			valueHint: 'L’affichage change. Les données, jamais.',
			privacyProofs: [
				{
					title: 'Sans compte Kara',
					body: 'Aucun identifiant supplémentaire à créer ou à confier.'
				},
				{
					title: 'iCloud privé',
					body: 'La synchronisation utilise votre base privée Apple.'
				},
				{
					title: 'Rapport local',
					body: 'Le PDF est composé sur l’appareil avant tout partage.'
				}
			],
			phoneNode: 'Votre iPhone',
			icloudNode: 'Votre iCloud privé',
			serverNode: 'Serveur Kara',
			serverNodeBody: 'Aucun inventaire',
			privacyLink: 'Lire notre engagement de confidentialité',
			finalTitle: 'Votre coffre. Enfin à sa place.',
			finalBody:
				'Un inventaire précis, une lecture claire et le contrôle qui va avec. Kara est disponible sur iPhone.',
			support: 'Assistance',
			privacy: 'Confidentialité',
			legal:
				'Les valorisations et simulations sont des estimations indicatives de valeur métal. Kara ne fournit aucun conseil financier ou fiscal.',
			heroScreen: '/landing/screens/fr/01-coffre.webp',
			heroScreenAlt: 'Coffre patrimonial Kara sur iPhone',
			privacyScreen: '/landing/screens/fr/08-confidentialite-icloud.webp',
			privacyScreenAlt: 'Réglages de confidentialité et iCloud dans Kara'
		},
		en: {
			metaTitle: 'KARA — A private vault for your precious-metal holdings',
			metaDescription:
				'Inventory bars, coins and jewellery, track their value and prepare calm decisions in a private vault synchronised through iCloud.',
			navExperience: 'Experience',
			navPrivacy: 'Privacy',
			appStore: 'Download',
			heroKicker: 'Private holdings vault',
			heroLineOne: 'Your holdings.',
			heroLineTwo: 'Under control.',
			heroBody:
				'Inventory your precious metals, track their value and prepare calm decisions in one private vault.',
			heroProof: 'No Kara account. Synced through iCloud.',
			explore: 'See the experience',
			scroll: 'Open the vault',
			metalsLabel: 'Kara tracks your physical precious metals',
			metals: ['Bars', 'Coins', 'Jewellery', 'Gold', 'Silver', 'Platinum', 'Palladium'],
			manifestoTitle: 'A digital vault for something very real.',
			manifestoBody:
				'Kara connects every object to what matters: its weight, purity, cost, documents and melt value. Not an abstract portfolio. Your physical holdings, finally made legible.',
			manifestoCaption: 'Every gram keeps its story.',
			manifestoScreen: '/landing/screens/en/03-asset-detail.webp',
			manifestoScreenAlt: 'Detailed view of a physical asset in Kara',
			showcaseTitle: 'Everything is here. Nothing gets buried.',
			showcaseBody:
				'An interface designed to make sense of your vault in seconds, then let you go as deep as you need.',
			showcase: [
				{
					title: 'Every asset, perfectly organised.',
					body:
						'Bars, coins, jewellery and custom assets remain easy to find, even as your vault grows.',
					note: 'Search · filters · tags',
					screen: '/landing/screens/en/02-inventory.webp',
					alt: 'Precious-metal inventory in Kara'
				},
				{
					title: 'See what is moving your vault.',
					body:
						'Current value, acquisition cost and unrealised gain are presented with the context that prevents false shortcuts.',
					note: 'Gold · silver · platinum · palladium',
					screen: '/landing/screens/en/04-performance.webp',
					alt: 'Vault performance analysis in Kara'
				},
				{
					title: 'Test a sale. Change nothing.',
					body:
						'Adjust a selection and its quantities, then compare estimated proceeds, prorated cost and potential gain.',
					note: 'Simulation without touching inventory',
					screen: '/landing/screens/en/06-price-goals-and-sales.webp',
					alt: 'Price goals and sales in Kara'
				},
				{
					title: 'Your evidence stays with your assets.',
					body:
						'Photos, invoices and certificates follow every record. A complete PDF report is generated locally when you choose.',
					note: 'Documents together · local report',
					screen: '/landing/screens/en/07-documents.webp',
					alt: 'Documents attached to an asset in Kara'
				}
			],
			journeyTitle: 'Understand before you decide.',
			journeyBody:
				'Kara does not push you to act. It gives you a calm, complete reading of what you hold.',
			journey: [
				{
					title: 'Inventory',
					body: 'Describe every object and its provenance precisely.'
				},
				{
					title: 'Value',
					body: 'Estimate its melt value from available spot prices.'
				},
				{
					title: 'Simulate',
					body: 'Explore a scenario without changing the vault.'
				},
				{
					title: 'Decide',
					body: 'Act with your own context, at the right time.'
				}
			],
			privacyTitle: 'Your inventory does not live with us.',
			privacyBody:
				'It stays on your iPhone and in your private iCloud database. Face ID protects access, values can disappear with one gesture, and Kara asks for no account.',
			estimatedValue: 'Estimated value',
			showValues: 'Show values',
			hideValues: 'Hide values',
			hiddenValue: '•••••',
			visibleValue: '€17,569',
			valueHint: 'The display changes. Your data does not.',
			privacyProofs: [
				{
					title: 'No Kara account',
					body: 'No additional identity to create or hand over.'
				},
				{
					title: 'Private iCloud',
					body: 'Sync uses your private Apple database.'
				},
				{
					title: 'Local report',
					body: 'The PDF is composed on device before you share it.'
				}
			],
			phoneNode: 'Your iPhone',
			icloudNode: 'Your private iCloud',
			serverNode: 'Kara server',
			serverNodeBody: 'No inventory',
			privacyLink: 'Read our privacy commitment',
			finalTitle: 'Your vault. Right where it belongs.',
			finalBody:
				'A precise inventory, a clear reading and the control that should come with both. Kara is available on iPhone.',
			support: 'Support',
			privacy: 'Privacy',
			legal:
				'Valuations and simulations are indicative melt-value estimates. Kara does not provide financial or tax advice.',
			heroScreen: '/landing/screens/en/01-vault.webp',
			heroScreenAlt: 'Kara private holdings vault on iPhone',
			privacyScreen: '/landing/screens/en/08-privacy-and-icloud.webp',
			privacyScreenAlt: 'Privacy and iCloud settings in Kara'
		}
	} satisfies Record<'fr' | 'en', LandingCopy>;

	const locale = $derived(getLocale() === 'fr' ? 'fr' : 'en');
	const copy = $derived(copyByLocale[locale]);
	const oppositeLocale = $derived(locale === 'fr' ? 'EN' : 'FR');
	const oppositeLocaleHref = $derived(locale === 'fr' ? '/en' : '/');
	const homeHref = $derived(locale === 'fr' ? '/' : '/en');
	const appStoreHref = publicConfig.appStoreUrl;
	const siteBaseUrl = publicConfig.siteUrl?.replace(/\/$/, '') ?? null;
	const canonicalUrl = $derived(siteBaseUrl ? `${siteBaseUrl}${locale === 'fr' ? '/' : '/en'}` : null);
	const socialImageUrl = siteBaseUrl ? `${siteBaseUrl}/brand/kara-og.png` : null;

	let pageRoot = $state<HTMLElement>();
	let activeShowcase = $state(0);
	let valuesVisible = $state(false);

	function localizedPath(path: string): string {
		return locale === 'fr' ? path : `/en${path}`;
	}

	/**
	 * Keeps the sticky product screen aligned with the narrative block crossing
	 * the centre of the viewport.
	 */
	function observeShowcaseStep(node: HTMLElement, index: number) {
		const observer = new IntersectionObserver(
			([entry]) => {
				if (entry.isIntersecting) activeShowcase = index;
			},
			{ rootMargin: '-42% 0px -42%', threshold: 0 }
		);

		observer.observe(node);
		return {
			destroy() {
				observer.disconnect();
			}
		};
	}

	onMount(() => {
		let cancelled = false;
		let revertAnimations: (() => void) | undefined;

		if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
			void (async () => {
				const [{ default: gsap }, { ScrollTrigger }] = await Promise.all([
					import('gsap'),
					import('gsap/ScrollTrigger')
				]);

				if (cancelled || !pageRoot) return;

				gsap.registerPlugin(ScrollTrigger);
				const context = gsap.context(() => {
					const load = gsap.timeline({ defaults: { ease: 'power4.out' } });
					load
						.from('.hero-word > span', {
							yPercent: 108,
							duration: 0.95,
							stagger: 0.09
						})
						.from(
							'.hero-animate',
							{ y: 22, opacity: 0, duration: 0.72, stagger: 0.08 },
							0.22
						)
						.from(
							'.aperture-rotator',
							{ scale: 0.72, rotation: -18, opacity: 0, duration: 1.25 },
							0.08
						)
						.from(
							'.hero-device',
							{ y: 90, rotation: 5, opacity: 0, duration: 1.08 },
							0.34
						);

					gsap.to('.aperture-rotator', {
						rotation: 72,
						scale: 1.12,
						ease: 'none',
						scrollTrigger: {
							trigger: '.hero',
							start: 'top top',
							end: 'bottom top',
							scrub: 1
						}
					});

					gsap.to('.hero-device', {
						yPercent: 18,
						rotation: -2.5,
						ease: 'none',
						scrollTrigger: {
							trigger: '.hero',
							start: 'top top',
							end: 'bottom top',
							scrub: 1
						}
					});

					gsap.utils.toArray<HTMLElement>('[data-parallax]').forEach((element, index) => {
						gsap.to(element, {
							yPercent: index % 2 === 0 ? -14 : 12,
							xPercent: index % 2 === 0 ? -5 : 4,
							ease: 'none',
							scrollTrigger: {
								trigger: element.closest('section') ?? element,
								start: 'top bottom',
								end: 'bottom top',
								scrub: 1.2
							}
						});
					});

					const manifestoMotion = gsap.timeline({
						scrollTrigger: {
							trigger: '.manifesto',
							start: 'top bottom',
							end: 'bottom top',
							scrub: 1.1
						}
					});

					manifestoMotion
						.fromTo(
							'.manifesto-vault__shell',
							{ scale: 0.96, rotation: -2.4, xPercent: 2 },
							{ scale: 1.08, rotation: 2.8, xPercent: -2, ease: 'none' },
							0
						)
						.fromTo(
							'.manifesto-vault__device',
							{ yPercent: 16, rotation: 2.5 },
							{ yPercent: -9, rotation: -2.2, ease: 'none' },
							0
						)
						.fromTo(
							'.manifesto-vault__glow',
							{ scale: 0.68, opacity: 0.28 },
							{ scale: 1.25, opacity: 0.78, ease: 'none' },
							0
						);

					gsap.to('.showcase-stage__dial', {
						rotation: 128,
						scale: 1.06,
						ease: 'none',
						scrollTrigger: {
							trigger: '.showcase',
							start: 'top bottom',
							end: 'bottom top',
							scrub: 1.2
						}
					});

					gsap.fromTo(
						'.journey-progress',
						{ scaleX: 0 },
						{
							scaleX: 1,
							ease: 'none',
							scrollTrigger: {
								trigger: '.journey',
								start: 'top 65%',
								end: 'bottom 70%',
								scrub: 0.8
							}
						}
					);

					gsap.fromTo(
						'.journey-step > span',
						{ scale: 0.35 },
						{
							scale: 1,
							stagger: 0.16,
							ease: 'power4.out',
							scrollTrigger: {
								trigger: '.journey-steps',
								start: 'top 78%',
								end: 'bottom 52%',
								scrub: 0.55
							}
						}
					);

					gsap.fromTo(
						'.privacy-orbit',
						{ scale: 0.78, rotation: -22 },
						{
							scale: 1.05,
							rotation: 48,
							ease: 'none',
							scrollTrigger: {
								trigger: '.privacy-section',
								start: 'top bottom',
								end: 'bottom top',
								scrub: 1
							}
						}
					);

					gsap.fromTo(
						'.final-aperture',
						{ scale: 0.78, rotation: -28, opacity: 0.12 },
						{
							scale: 1.12,
							rotation: 44,
							opacity: 0.42,
							ease: 'none',
							scrollTrigger: {
								trigger: '.final-cta',
								start: 'top bottom',
								end: 'bottom top',
								scrub: 1.1
							}
						}
					);

					gsap.fromTo(
						'.final-glow',
						{ scale: 0.72, opacity: 0.18 },
						{
							scale: 1.24,
							opacity: 0.62,
							ease: 'none',
							scrollTrigger: {
								trigger: '.final-cta',
								start: 'top bottom',
								end: 'bottom top',
								scrub: 1.1
							}
						}
					);
				}, pageRoot);

				revertAnimations = () => context.revert();
			})();
		}

		return () => {
			cancelled = true;
			revertAnimations?.();
		};
	});
</script>

{#snippet appStoreLink(className: string, label: string)}
	{#if appStoreHref}
		<a class={className} href={appStoreHref} target="_blank" rel="noreferrer">
			<AppleIcon size={18} strokeWidth={1.8} aria-hidden="true" />
			<span>{label}</span>
		</a>
	{:else}
		<a class={className} href="#experience">
			<span>{copy.explore}</span>
			<ArrowRightIcon size={18} strokeWidth={1.8} aria-hidden="true" />
		</a>
	{/if}
{/snippet}

<svelte:head>
	<title>{copy.metaTitle}</title>
	<meta name="description" content={copy.metaDescription} />
	<meta property="og:title" content={copy.metaTitle} />
	<meta property="og:description" content={copy.metaDescription} />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="KARA" />
	<meta property="og:locale" content={locale === 'fr' ? 'fr_FR' : 'en_US'} />
	{#if canonicalUrl}
		<link rel="canonical" href={canonicalUrl} />
		<meta property="og:url" content={canonicalUrl} />
	{/if}
	{#if socialImageUrl}
		<meta property="og:image" content={socialImageUrl} />
		<meta
			property="og:image:alt"
			content={locale === 'fr'
				? 'Kara, l’inventaire privé de vos actifs réels'
				: 'Kara, the private inventory for your real-world assets'}
		/>
		<meta property="og:image:width" content="1200" />
		<meta property="og:image:height" content="630" />
		<meta name="twitter:image" content={socialImageUrl} />
	{/if}
	<meta name="twitter:card" content="summary_large_image" />
</svelte:head>

<div class="kara-landing" bind:this={pageRoot}>
	<SiteHeader mode="overlay" />

	<main id="main-content">
		<section class="hero relative isolate flex min-h-[100svh] items-center overflow-hidden">
			<div class="hero-light" aria-hidden="true"></div>
			<div
				class="mx-auto grid w-full max-w-[90rem] items-center gap-12 px-4 pb-20 pt-32 sm:px-8 lg:grid-cols-[0.92fr_1.08fr] lg:px-12 lg:pb-24 lg:pt-28"
			>
				<div class="hero-copy relative z-10">
					<p class="hero-kicker hero-animate">{copy.heroKicker}</p>
					<h1>
						<span class="hero-word"><span>{copy.heroLineOne}</span></span>
						<span class="hero-word hero-word--gold"><span>{copy.heroLineTwo}</span></span>
					</h1>
					<p class="hero-body hero-animate">{copy.heroBody}</p>

					<div class="hero-actions hero-animate">
						{@render appStoreLink('primary-cta', copy.appStore)}
						<a class="secondary-cta" href={appStoreHref ? '#experience' : '#confidentialite'}>
							<span>{appStoreHref ? copy.explore : copy.navPrivacy}</span>
							<ArrowDownIcon size={18} strokeWidth={1.8} aria-hidden="true" />
						</a>
					</div>

					<p class="hero-proof hero-animate">
						<span aria-hidden="true"></span>
						{copy.heroProof}
					</p>
				</div>

				<div class="hero-visual" aria-label={copy.heroScreenAlt}>
					<div class="aperture-rotator">
						<VaultAperture />
					</div>
					<div class="hero-metal hero-metal--ring" data-parallax aria-hidden="true">
						<img src="/landing/materials/gold-ring.webp" alt="" width="1536" height="1024" />
					</div>
					<DeviceFrame
						class="hero-device"
						src={copy.heroScreen}
						alt={copy.heroScreenAlt}
						priority={true}
					/>
				</div>
			</div>

			<a class="scroll-cue" href="#manifeste">
				<span>{copy.scroll}</span>
				<ArrowDownIcon size={16} strokeWidth={1.8} aria-hidden="true" />
			</a>
		</section>

		<section class="metal-ticker" aria-label={copy.metalsLabel}>
			<p class="sr-only">{copy.metals.join(', ')}</p>
			<div class="metal-ticker__track" aria-hidden="true">
				{#each [...copy.metals, ...copy.metals] as metal}
					<span>{metal}</span>
					<i></i>
				{/each}
			</div>
		</section>

		<section id="manifeste" class="manifesto relative isolate overflow-hidden">
			<div
				class="manifesto-grid mx-auto grid w-full max-w-[90rem] gap-12 px-4 py-28 sm:px-8 md:py-36 lg:px-12 lg:py-44"
			>
				<h2>{copy.manifestoTitle}</h2>
				<div class="manifesto-copy">
					<p>{copy.manifestoBody}</p>
					<span>{copy.manifestoCaption}</span>
				</div>
			</div>

			<div class="manifesto-vault">
				<div class="manifesto-vault__glow" aria-hidden="true"></div>
				<img
					class="manifesto-vault__shell"
					src="/landing/materials/manifesto-vault-v2.webp"
					alt=""
					width="1754"
					height="896"
					loading="lazy"
					decoding="async"
				/>
				<div class="manifesto-vault__device">
					<DeviceFrame src={copy.manifestoScreen} alt={copy.manifestoScreenAlt} />
				</div>
			</div>
		</section>

		<section id="experience" class="showcase">
			<div class="showcase-heading mx-auto w-full max-w-[90rem] px-4 sm:px-8 lg:px-12">
				<h2>{copy.showcaseTitle}</h2>
				<p>{copy.showcaseBody}</p>
			</div>

			<div class="showcase-layout mx-auto w-full max-w-[90rem] px-4 sm:px-8 lg:px-12">
				<div class="showcase-steps">
					{#each copy.showcase as item, index}
						<article
							class:active={activeShowcase === index}
							class="showcase-step"
							use:observeShowcaseStep={index}
						>
							<span class="showcase-step__signal" aria-hidden="true"></span>
							<h3>{item.title}</h3>
							<p>{item.body}</p>
							<small>{item.note}</small>
							<div class="showcase-mobile-device">
								<DeviceFrame src={item.screen} alt={item.alt} />
							</div>
						</article>
					{/each}
				</div>

				<div class="showcase-stage" aria-live="polite">
					<div class="showcase-stage__light" aria-hidden="true"></div>
					<div class="showcase-stage__dial" aria-hidden="true">
						<span></span>
					</div>
					{#each copy.showcase as item, index}
						<div class:active={activeShowcase === index} class="showcase-screen">
							<DeviceFrame src={item.screen} alt={item.alt} />
						</div>
					{/each}

					<div class="showcase-dots" aria-label={locale === 'fr' ? 'Écrans présentés' : 'Screens shown'}>
						{#each copy.showcase as item, index}
							<button
								type="button"
								class:active={activeShowcase === index}
								onclick={() => (activeShowcase = index)}
								aria-label={item.title}
								aria-pressed={activeShowcase === index}
							></button>
						{/each}
					</div>
				</div>
			</div>
		</section>

		<section class="journey relative isolate overflow-hidden">
			<div class="journey-material" data-parallax aria-hidden="true">
				<img src="/landing/materials/silver-coin.webp" alt="" width="1536" height="1024" />
			</div>

			<div class="mx-auto w-full max-w-[90rem] px-4 py-28 sm:px-8 md:py-40 lg:px-12">
				<div class="journey-heading">
					<h2>{copy.journeyTitle}</h2>
					<p>{copy.journeyBody}</p>
				</div>

				<div class="journey-steps">
					<div class="journey-line" aria-hidden="true">
						<span class="journey-progress"></span>
					</div>
					{#each copy.journey as step}
						<div class="journey-step">
							<span aria-hidden="true"></span>
							<h3>{step.title}</h3>
							<p>{step.body}</p>
						</div>
					{/each}
				</div>
			</div>
		</section>

		<section id="confidentialite" class="privacy-section relative isolate overflow-hidden">
			<div class="privacy-glow" aria-hidden="true"></div>
			<div
				class="mx-auto grid w-full max-w-[90rem] items-center gap-16 px-4 py-28 sm:px-8 md:py-36 lg:grid-cols-[0.92fr_1.08fr] lg:px-12 lg:py-44"
			>
				<div class="privacy-visual">
					<div class="privacy-orbit" aria-hidden="true">
						<span></span>
						<span></span>
						<span></span>
					</div>
					<DeviceFrame
						class="privacy-device"
						src={copy.privacyScreen}
						alt={copy.privacyScreenAlt}
					/>
					<div class="privacy-map" aria-hidden="true">
						<div class="privacy-node privacy-node--phone">
							<LockKeyholeIcon size={18} strokeWidth={1.8} />
							<span>{copy.phoneNode}</span>
						</div>
						<div class="privacy-connector"></div>
						<div class="privacy-node privacy-node--cloud">
							<CloudIcon size={18} strokeWidth={1.8} />
							<span>{copy.icloudNode}</span>
						</div>
						<div class="privacy-node privacy-node--server">
							<span>{copy.serverNode}</span>
							<small>{copy.serverNodeBody}</small>
						</div>
					</div>
				</div>

				<div class="privacy-copy">
					<h2>{copy.privacyTitle}</h2>
					<p class="privacy-lead">{copy.privacyBody}</p>

					<div class="sensitive-demo">
						<div>
							<span>{copy.estimatedValue}</span>
							<strong>{valuesVisible ? copy.visibleValue : copy.hiddenValue}</strong>
						</div>
						<button
							type="button"
							onclick={() => (valuesVisible = !valuesVisible)}
							aria-pressed={valuesVisible}
							aria-label={valuesVisible ? copy.hideValues : copy.showValues}
						>
							{#if valuesVisible}
								<EyeOffIcon size={21} strokeWidth={1.8} aria-hidden="true" />
							{:else}
								<EyeIcon size={21} strokeWidth={1.8} aria-hidden="true" />
							{/if}
						</button>
						<small>{copy.valueHint}</small>
					</div>

					<div class="privacy-proofs">
						{#each copy.privacyProofs as proof, index}
							<div>
								<span aria-hidden="true">
									{#if index === 0}
										<ShieldCheckIcon size={22} strokeWidth={1.7} />
									{:else if index === 1}
										<CloudIcon size={22} strokeWidth={1.7} />
									{:else}
										<FileTextIcon size={22} strokeWidth={1.7} />
									{/if}
								</span>
								<p><strong>{proof.title}</strong>{proof.body}</p>
							</div>
						{/each}
					</div>

					<a class="privacy-link" href={localizedPath('/privacy')}>
						<span>{copy.privacyLink}</span>
						<ArrowRightIcon size={18} strokeWidth={1.8} aria-hidden="true" />
					</a>
				</div>
			</div>
		</section>

		<section id="download" class="final-cta relative isolate overflow-hidden">
			<div class="final-aperture" aria-hidden="true">
				<VaultAperture />
			</div>
			<div class="final-glow" aria-hidden="true"></div>
			<div class="mx-auto w-full max-w-[90rem] px-4 pb-28 pt-32 sm:px-8 md:py-44 lg:px-12">
				<h2>{copy.finalTitle}</h2>
				<p>{copy.finalBody}</p>
				{@render appStoreLink('final-download', copy.appStore)}
			</div>
		</section>
	</main>

	<footer class="site-footer">
		<div
			class="mx-auto flex w-full max-w-[90rem] flex-col gap-8 px-4 py-10 sm:px-8 md:flex-row md:items-end md:justify-between lg:px-12"
		>
			<div>
				<a class="footer-brand" href={homeHref}>KARA</a>
				<p>{copy.legal}</p>
			</div>
			<div class="footer-links">
				<a href={localizedPath('/support')}>{copy.support}</a>
				<a href={localizedPath('/privacy')}>{copy.privacy}</a>
				<a href={oppositeLocaleHref} hreflang={locale === 'fr' ? 'en' : 'fr'}>
					{oppositeLocale}
				</a>
			</div>
		</div>
	</footer>
</div>

<style>
	:global(body) {
		background: oklch(0.055 0.004 258);
	}

	:global(.sr-only) {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}

	.kara-landing {
		--landing-void: oklch(0.055 0.004 258);
		--landing-void-soft: oklch(0.085 0.012 258);
		--landing-surface: oklch(0.12 0.016 258);
		--landing-ink: oklch(0.965 0.006 95);
		--landing-muted: oklch(0.73 0.018 258);
		--landing-line: oklch(0.35 0.026 258);
		--landing-cobalt: oklch(0.56 0.2 258);
		--landing-cobalt-bright: oklch(0.74 0.15 258);
		--landing-gold: oklch(0.86 0.12 92);
		--landing-positive: oklch(0.76 0.15 153);
		position: relative;
		overflow: clip;
		background: var(--landing-void);
		color: var(--landing-ink);
		font-family: 'Geologica Variable', 'Arial Fallback', sans-serif;
	}

	.kara-landing :global(a),
	.kara-landing button {
		-webkit-tap-highlight-color: transparent;
	}

	.kara-landing :global(a:focus-visible),
	.kara-landing button:focus-visible {
		outline: 2px solid var(--landing-cobalt-bright);
		outline-offset: 4px;
	}

	.primary-cta,
	.secondary-cta,
	.final-download {
		display: inline-flex;
		min-height: 3rem;
		align-items: center;
		justify-content: center;
		gap: 0.65rem;
		border-radius: 999px;
		text-decoration: none;
		transition:
			transform 180ms var(--ease-out-quart),
			background-color 180ms var(--ease-out-quart),
			color 180ms var(--ease-out-quart);
	}

	.hero {
		background:
			radial-gradient(circle at 78% 46%, oklch(0.27 0.16 258 / 0.34), transparent 33%),
			linear-gradient(120deg, oklch(0.045 0.004 258), oklch(0.07 0.016 258) 72%, oklch(0.04 0.006 258));
	}

	.hero::after {
		position: absolute;
		right: 0;
		bottom: 0;
		left: 0;
		height: 25%;
		background: linear-gradient(transparent, var(--landing-void));
		pointer-events: none;
		content: '';
	}

	.hero-light {
		position: absolute;
		top: 8%;
		right: 2%;
		width: min(72vw, 62rem);
		aspect-ratio: 1;
		border-radius: 50%;
		background: oklch(0.56 0.2 258 / 0.11);
		filter: blur(5rem);
	}

	.hero-copy {
		max-width: 43rem;
	}

	.hero-kicker {
		margin: 0 0 1.5rem;
		color: var(--landing-gold);
		font-size: 0.75rem;
		font-weight: 620;
		letter-spacing: 0.16em;
		text-transform: uppercase;
	}

	h1 {
		max-width: 12ch;
		margin: 0;
		font-size: clamp(3.35rem, 6.7vw, 6rem);
		font-weight: 520;
		letter-spacing: -0.038em;
		line-height: 0.96;
		text-wrap: balance;
	}

	.hero-word {
		display: block;
		overflow: hidden;
		padding-bottom: 0.08em;
	}

	.hero-word > span {
		display: block;
	}

	.hero-word--gold {
		color: var(--landing-gold);
	}

	.hero-body {
		max-width: 35rem;
		margin: 2rem 0 0;
		color: var(--landing-muted);
		font-size: clamp(1.05rem, 1.7vw, 1.28rem);
		font-weight: 370;
		line-height: 1.62;
		text-wrap: pretty;
	}

	.hero-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.8rem;
		margin-top: 2rem;
	}

	.primary-cta {
		padding: 0 1.35rem;
		background: var(--landing-gold);
		color: oklch(0.12 0.016 88);
		font-size: 0.875rem;
		font-weight: 650;
	}

	.secondary-cta {
		padding: 0 1.25rem;
		border: 1px solid oklch(0.86 0.12 92 / 0.42);
		color: var(--landing-gold);
		font-size: 0.875rem;
		font-weight: 520;
	}

	.primary-cta:hover,
	.final-download:hover {
		background: oklch(0.91 0.1 96);
		transform: translateY(-2px);
	}

	.secondary-cta:hover {
		background: oklch(0.86 0.12 92 / 0.08);
		transform: translateY(-2px);
	}

	.primary-cta:active,
	.secondary-cta:active,
	.final-download:active {
		transform: translateY(0) scale(0.98);
	}

	.hero-proof {
		display: flex;
		align-items: center;
		gap: 0.65rem;
		margin: 1.25rem 0 0;
		color: oklch(0.79 0.014 258);
		font-size: 0.875rem;
		line-height: 1.5;
	}

	.hero-proof span {
		width: 0.42rem;
		height: 0.42rem;
		border-radius: 50%;
		background: var(--landing-positive);
		box-shadow: 0 0 0 0.24rem oklch(0.76 0.15 153 / 0.12);
	}

	.hero-visual {
		position: relative;
		z-index: 1;
		display: grid;
		min-height: min(73vh, 48rem);
		place-items: center;
	}

	.aperture-rotator {
		position: absolute;
		width: min(51rem, 67vw);
	}

	.hero-visual :global(.hero-device) {
		z-index: 4;
		width: min(19.5rem, 48vw);
		margin-left: 14%;
	}

	.hero-metal {
		position: absolute;
		z-index: 3;
		width: clamp(9rem, 18vw, 16rem);
		aspect-ratio: 1.5;
		overflow: hidden;
		pointer-events: none;
		-webkit-mask-image: radial-gradient(ellipse, #000 24%, transparent 72%);
		mask-image: radial-gradient(ellipse, #000 24%, transparent 72%);
	}

	.hero-metal img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.hero-metal--ring {
		right: -2%;
		bottom: 16%;
		transform: rotate(11deg);
	}

	.scroll-cue {
		position: absolute;
		bottom: 1.5rem;
		left: 50%;
		z-index: 3;
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		gap: 0.65rem;
		color: oklch(0.75 0.016 258);
		font-size: 0.75rem;
		text-decoration: none;
		transform: translateX(-50%);
	}

	.scroll-cue :global(svg) {
		animation: scroll-pulse 1.8s var(--ease-out-quart) infinite;
	}

	@keyframes scroll-pulse {
		0%,
		100% {
			transform: translateY(0);
		}
		50% {
			transform: translateY(0.32rem);
		}
	}

	.metal-ticker {
		position: relative;
		z-index: 3;
		overflow: hidden;
		border-block: 1px solid oklch(0.35 0.026 258 / 0.7);
		background: oklch(0.075 0.012 258);
	}

	.metal-ticker__track {
		display: flex;
		width: max-content;
		align-items: center;
		gap: 1.5rem;
		padding: 1rem 0;
		animation: ticker 34s linear infinite;
	}

	.metal-ticker__track span {
		color: oklch(0.83 0.02 258);
		font-size: 0.75rem;
		font-weight: 560;
		letter-spacing: 0.16em;
		text-transform: uppercase;
	}

	.metal-ticker__track i {
		width: 0.28rem;
		height: 0.28rem;
		border-radius: 50%;
		background: var(--landing-gold);
	}

	@keyframes ticker {
		to {
			transform: translateX(-50%);
		}
	}

	.manifesto {
		min-height: 78vh;
		background: var(--landing-void);
	}

	.manifesto h2,
	.showcase-heading h2,
	.journey h2,
	.privacy-section h2,
	.final-cta h2 {
		margin: 0;
		font-size: clamp(2.65rem, 5vw, 4.9rem);
		font-weight: 510;
		letter-spacing: -0.035em;
		line-height: 1.02;
		text-wrap: balance;
	}

	.manifesto h2 {
		position: relative;
		z-index: 2;
		max-width: 14ch;
	}

	.manifesto-copy {
		position: relative;
		z-index: 2;
		align-self: end;
		max-width: 34rem;
		padding-top: 1rem;
	}

	.manifesto-copy p {
		margin: 0;
		color: var(--landing-muted);
		font-size: clamp(1.05rem, 1.8vw, 1.3rem);
		line-height: 1.72;
		text-wrap: pretty;
	}

	.manifesto-copy span {
		display: inline-block;
		margin-top: 2rem;
		color: var(--landing-gold);
		font-size: 0.75rem;
		font-weight: 560;
		letter-spacing: 0.08em;
	}

	.manifesto-vault {
		position: absolute;
		top: 50%;
		right: -7%;
		left: 35%;
		z-index: 1;
		aspect-ratio: 1754 / 896;
		isolation: isolate;
		pointer-events: none;
		translate: 0 -50%;
	}

	.manifesto-vault__shell {
		position: absolute;
		inset: 0;
		z-index: 1;
		width: 100%;
		height: 100%;
		max-width: none;
		object-fit: contain;
		transform-origin: 55% 50%;
	}

	.manifesto-vault__glow {
		position: absolute;
		top: 19%;
		left: 40%;
		z-index: 0;
		width: 31%;
		aspect-ratio: 1;
		border-radius: 50%;
		background: oklch(0.58 0.22 258 / 0.54);
		filter: blur(4.5rem);
	}

	.manifesto-vault__device {
		position: absolute;
		top: 48.5%;
		left: 55.2%;
		z-index: 2;
		width: clamp(8.5rem, 10vw, 10rem);
		translate: -50% -50%;
	}

	.manifesto-vault__device :global(.device) {
		width: 100%;
		filter: drop-shadow(0 1.6rem 2rem oklch(0% 0 0 / 0.72));
	}

	.showcase {
		position: relative;
		padding: clamp(7rem, 12vw, 11rem) 0;
		background:
			radial-gradient(circle at 82% 32%, oklch(0.28 0.14 258 / 0.22), transparent 25%),
			var(--landing-surface);
	}

	.showcase-heading {
		display: grid;
		gap: 2rem;
		align-items: end;
		padding-bottom: clamp(4rem, 8vw, 7rem);
	}

	.showcase-heading h2 {
		max-width: 13ch;
	}

	.showcase-heading > p {
		max-width: 38rem;
		margin: 0;
		color: var(--landing-muted);
		font-size: 1.125rem;
		line-height: 1.7;
		text-wrap: pretty;
	}

	.showcase-layout {
		display: grid;
		grid-template-columns: minmax(0, 0.92fr) minmax(22rem, 1.08fr);
		gap: clamp(3rem, 8vw, 9rem);
	}

	.showcase-step {
		position: relative;
		display: flex;
		min-height: 68vh;
		flex-direction: column;
		justify-content: center;
		padding: 4rem 0 4rem 2rem;
		border-top: 1px solid oklch(0.35 0.026 258 / 0.72);
		opacity: 0.72;
		transition:
			opacity 350ms var(--ease-out-quart),
			color 350ms var(--ease-out-quart);
	}

	.showcase-step:last-child {
		border-bottom: 1px solid oklch(0.35 0.026 258 / 0.72);
	}

	.showcase-step.active {
		opacity: 1;
	}

	.showcase-step__signal {
		position: absolute;
		top: 50%;
		left: 0;
		width: 0.54rem;
		height: 0.54rem;
		border-radius: 50%;
		background: var(--landing-cobalt-bright);
		box-shadow: 0 0 0 0.35rem oklch(0.74 0.15 258 / 0.1);
		transform: translateY(-50%) scale(0.55);
		transition: transform 350ms var(--ease-out-expo);
	}

	.showcase-step.active .showcase-step__signal {
		transform: translateY(-50%) scale(1);
	}

	.showcase-step h3 {
		max-width: 12ch;
		margin: 0;
		font-size: clamp(2rem, 3.2vw, 3.35rem);
		font-weight: 510;
		letter-spacing: -0.03em;
		line-height: 1.06;
		text-wrap: balance;
	}

	.showcase-step > p {
		max-width: 34rem;
		margin: 1.35rem 0 0;
		color: var(--landing-muted);
		font-size: 1rem;
		line-height: 1.7;
		text-wrap: pretty;
	}

	.showcase-step small {
		margin-top: 1.5rem;
		color: var(--landing-cobalt-bright);
		font-size: 0.75rem;
		font-weight: 560;
		letter-spacing: 0.035em;
	}

	.showcase-mobile-device {
		display: none;
	}

	.showcase-stage {
		position: sticky;
		top: 8vh;
		display: grid;
		height: 84vh;
		place-items: center;
		align-self: start;
		overflow: hidden;
		isolation: isolate;
	}

	.showcase-stage__light {
		position: absolute;
		z-index: -1;
		width: 80%;
		aspect-ratio: 1;
		border-radius: 50%;
		background: oklch(0.56 0.2 258 / 0.16);
		filter: blur(4rem);
	}

	.showcase-stage__dial {
		position: absolute;
		z-index: 0;
		width: min(43rem, 94%);
		aspect-ratio: 1;
		border-radius: 50%;
		background: repeating-conic-gradient(
			from 0deg,
			oklch(0.86 0.12 92 / 0.52) 0deg 0.45deg,
			transparent 0.45deg 6deg
		);
		opacity: 0.52;
		-webkit-mask: radial-gradient(
			circle,
			transparent 0 61%,
			#000 61.3% 62%,
			transparent 62.3% 75%,
			#000 75.3% 76%,
			transparent 76.3%
		);
		mask: radial-gradient(
			circle,
			transparent 0 61%,
			#000 61.3% 62%,
			transparent 62.3% 75%,
			#000 75.3% 76%,
			transparent 76.3%
		);
		pointer-events: none;
	}

	.showcase-stage__dial span {
		position: absolute;
		inset: 23%;
		border: 1px solid oklch(0.74 0.15 258 / 0.48);
		border-radius: 50%;
	}

	.showcase-stage__dial span::before {
		position: absolute;
		top: -0.28rem;
		left: 50%;
		width: 0.56rem;
		height: 0.56rem;
		border-radius: 50%;
		background: var(--landing-gold);
		box-shadow: 0 0 1rem oklch(0.86 0.12 92 / 0.72);
		content: '';
		transform: translateX(-50%);
	}

	.showcase-screen {
		position: absolute;
		z-index: 2;
		display: grid;
		width: min(21rem, 76%);
		place-items: center;
		opacity: 0;
		filter: blur(0.5rem) saturate(0.72);
		transform: translateY(4rem) scale(0.88) rotate(3deg);
		transition:
			opacity 420ms var(--ease-out-quart),
			filter 500ms var(--ease-out-quart),
			transform 720ms var(--ease-out-expo);
		transform-origin: center bottom;
		pointer-events: none;
	}

	.showcase-screen.active {
		opacity: 1;
		filter: blur(0) saturate(1);
		transform: translateY(0) scale(1) rotate(0);
	}

	.showcase-dots {
		position: absolute;
		right: 1rem;
		bottom: 2rem;
		left: 1rem;
		z-index: 4;
		display: flex;
		justify-content: center;
		gap: 0.7rem;
	}

	.showcase-dots button {
		position: relative;
		width: 2.75rem;
		height: 2.75rem;
		padding: 0;
		border: 0;
		background: transparent;
		cursor: pointer;
	}

	.showcase-dots button::after {
		position: absolute;
		top: 50%;
		left: 50%;
		width: 1.5rem;
		height: 2px;
		background: oklch(0.48 0.03 258);
		content: '';
		transform: translate(-50%, -50%);
		transition:
			width 250ms var(--ease-out-quart),
			background-color 250ms var(--ease-out-quart);
	}

	.showcase-dots button.active::after {
		width: 2.25rem;
		background: var(--landing-gold);
	}

	.journey {
		min-height: 90vh;
		background: var(--landing-void);
	}

	.journey-material {
		position: absolute;
		right: -13%;
		bottom: -8%;
		width: min(61vw, 58rem);
		aspect-ratio: 1.5;
		opacity: 0.55;
		-webkit-mask-image: radial-gradient(ellipse at 56% 52%, #000 20%, transparent 70%);
		mask-image: radial-gradient(ellipse at 56% 52%, #000 20%, transparent 70%);
	}

	.journey-material::after {
		position: absolute;
		inset: 0;
		background: linear-gradient(90deg, var(--landing-void), transparent 55%);
		content: '';
	}

	.journey-material img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.journey-heading {
		position: relative;
		z-index: 2;
		display: grid;
		gap: 2rem;
	}

	.journey-heading h2 {
		max-width: 13ch;
	}

	.journey-heading p {
		max-width: 35rem;
		margin: 0;
		color: var(--landing-muted);
		font-size: 1.125rem;
		line-height: 1.7;
	}

	.journey-steps {
		position: relative;
		z-index: 2;
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 2rem;
		margin-top: clamp(5rem, 10vw, 9rem);
	}

	.journey-line {
		position: absolute;
		top: 0.28rem;
		right: 0;
		left: 0;
		height: 1px;
		overflow: hidden;
		background: oklch(0.35 0.026 258);
	}

	.journey-progress {
		display: block;
		width: 100%;
		height: 100%;
		background: var(--landing-gold);
		transform-origin: left;
	}

	.journey-step {
		padding-top: 2.2rem;
	}

	.journey-step > span {
		position: absolute;
		top: 0;
		width: 0.6rem;
		height: 0.6rem;
		border-radius: 50%;
		background: var(--landing-gold);
		transform: translateY(-0.02rem);
	}

	.journey-step h3 {
		margin: 0;
		font-size: clamp(1.2rem, 2vw, 1.55rem);
		font-weight: 560;
		letter-spacing: -0.018em;
	}

	.journey-step p {
		max-width: 17rem;
		margin: 0.8rem 0 0;
		color: var(--landing-muted);
		font-size: 1rem;
		line-height: 1.65;
	}

	.privacy-section {
		background: oklch(0.28 0.14 258);
	}

	.privacy-section::before {
		position: absolute;
		inset: 0;
		background:
			radial-gradient(circle at 24% 52%, oklch(0.62 0.22 258 / 0.38), transparent 32%),
			linear-gradient(120deg, transparent 54%, oklch(0.13 0.08 258 / 0.52));
		content: '';
	}

	.privacy-glow {
		position: absolute;
		top: 18%;
		left: 8%;
		width: 34rem;
		aspect-ratio: 1;
		border-radius: 50%;
		background: oklch(0.72 0.2 258 / 0.24);
		filter: blur(6rem);
	}

	.privacy-visual {
		position: relative;
		display: grid;
		min-height: 48rem;
		place-items: center;
	}

	.privacy-visual :global(.privacy-device) {
		z-index: 3;
		width: min(18rem, 62vw);
		transform: rotate(-3deg);
	}

	.privacy-orbit {
		position: absolute;
		width: min(39rem, 80vw);
		aspect-ratio: 1;
		border: 1px solid oklch(0.82 0.12 258 / 0.38);
		border-radius: 50%;
	}

	.privacy-orbit::before,
	.privacy-orbit::after {
		position: absolute;
		border: 1px solid oklch(0.82 0.12 258 / 0.24);
		border-radius: 50%;
		content: '';
	}

	.privacy-orbit::before {
		inset: 9%;
	}

	.privacy-orbit::after {
		inset: 20%;
	}

	.privacy-orbit > span {
		position: absolute;
		width: 0.72rem;
		height: 0.72rem;
		border-radius: 50%;
		background: var(--landing-gold);
		box-shadow: 0 0 1.2rem oklch(0.86 0.12 92 / 0.8);
	}

	.privacy-orbit > span:nth-child(1) {
		top: 7%;
		left: 30%;
	}

	.privacy-orbit > span:nth-child(2) {
		right: 4%;
		bottom: 34%;
	}

	.privacy-orbit > span:nth-child(3) {
		bottom: 10%;
		left: 18%;
	}

	.privacy-map {
		position: absolute;
		inset: 0;
		z-index: 4;
		pointer-events: none;
	}

	.privacy-node {
		position: absolute;
		display: inline-flex;
		min-height: 2.8rem;
		align-items: center;
		gap: 0.55rem;
		padding: 0 0.9rem;
		border-radius: 999px;
		background: oklch(0.12 0.06 258);
		color: oklch(0.94 0.02 258);
		font-size: 0.75rem;
		font-weight: 520;
	}

	.privacy-node--phone {
		top: 20%;
		left: -2%;
	}

	.privacy-node--cloud {
		right: -1%;
		bottom: 25%;
		background: var(--landing-gold);
		color: oklch(0.16 0.03 88);
	}

	.privacy-node--server {
		right: 0;
		top: 17%;
		display: flex;
		min-height: 3.4rem;
		flex-direction: column;
		align-items: flex-start;
		justify-content: center;
		gap: 0;
		border: 1px dashed oklch(0.92 0.02 258 / 0.42);
		background: oklch(0.18 0.08 258 / 0.68);
		opacity: 0.62;
	}

	.privacy-node--server::after {
		position: absolute;
		right: 0.6rem;
		left: 0.6rem;
		height: 1px;
		background: oklch(0.96 0.01 258 / 0.7);
		content: '';
		transform: rotate(-9deg);
	}

	.privacy-node--server small {
		font-size: 0.75rem;
		opacity: 0.78;
	}

	.privacy-connector {
		position: absolute;
		right: 13%;
		bottom: 32%;
		width: 20%;
		height: 1px;
		background: oklch(0.86 0.12 92 / 0.65);
		transform: rotate(-22deg);
		transform-origin: right;
	}

	.privacy-copy {
		position: relative;
		z-index: 2;
	}

	.privacy-copy h2 {
		max-width: 12ch;
	}

	.privacy-lead {
		max-width: 39rem;
		margin: 1.8rem 0 0;
		color: oklch(0.92 0.025 258 / 0.84);
		font-size: 1.125rem;
		line-height: 1.72;
		text-wrap: pretty;
	}

	.sensitive-demo {
		position: relative;
		display: grid;
		grid-template-columns: 1fr auto;
		gap: 0.65rem 1rem;
		max-width: 34rem;
		margin-top: 2.5rem;
		padding: 1.4rem;
		border-radius: 0.9rem;
		background: oklch(0.13 0.07 258);
		box-shadow: inset 0 0 0 1px oklch(0.88 0.08 258 / 0.16);
	}

	.sensitive-demo > div {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.sensitive-demo span {
		color: oklch(0.86 0.04 258 / 0.8);
		font-size: 0.875rem;
	}

	.sensitive-demo strong {
		min-width: 8ch;
		font-size: clamp(1.75rem, 3vw, 2.5rem);
		font-weight: 520;
		letter-spacing: -0.03em;
	}

	.sensitive-demo button {
		width: 2.75rem;
		height: 2.75rem;
		padding: 0;
		border: 0;
		border-radius: 50%;
		background: oklch(0.62 0.2 258);
		color: white;
		cursor: pointer;
		transition:
			transform 160ms var(--ease-out-quart),
			background-color 160ms var(--ease-out-quart);
	}

	.sensitive-demo button:hover {
		background: oklch(0.7 0.18 258);
		transform: scale(1.04);
	}

	.sensitive-demo small {
		grid-column: 1 / -1;
		color: oklch(0.86 0.04 258 / 0.68);
		font-size: 0.875rem;
		line-height: 1.5;
	}

	.privacy-proofs {
		display: grid;
		gap: 0;
		max-width: 37rem;
		margin-top: 2.25rem;
	}

	.privacy-proofs > div {
		display: grid;
		grid-template-columns: 2.6rem 1fr;
		gap: 0.9rem;
		align-items: start;
		padding: 1rem 0;
		border-bottom: 1px solid oklch(0.88 0.08 258 / 0.18);
	}

	.privacy-proofs > div > span {
		display: grid;
		width: 2.25rem;
		height: 2.25rem;
		place-items: center;
		border-radius: 50%;
		background: oklch(0.68 0.19 258 / 0.34);
		color: var(--landing-gold);
	}

	.privacy-proofs p {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		margin: 0;
		color: oklch(0.91 0.025 258 / 0.76);
		font-size: 1rem;
		line-height: 1.55;
	}

	.privacy-proofs strong {
		color: white;
		font-size: 1rem;
		font-weight: 570;
	}

	.privacy-link {
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		gap: 0.65rem;
		margin-top: 1.6rem;
		color: var(--landing-gold);
		font-size: 0.875rem;
		font-weight: 560;
		text-decoration: none;
	}

	.privacy-link :global(svg) {
		transition: transform 180ms var(--ease-out-quart);
	}

	.privacy-link:hover :global(svg) {
		transform: translateX(0.25rem);
	}

	.final-cta {
		min-height: 82vh;
		display: flex;
		align-items: center;
		background:
			radial-gradient(circle at 77% 54%, oklch(0.23 0.1 258 / 0.34), transparent 32%),
			var(--landing-void);
	}

	.final-cta > div:last-child {
		position: relative;
		z-index: 2;
	}

	.final-cta h2 {
		max-width: 12ch;
		font-size: clamp(3.2rem, 7vw, 6rem);
	}

	.final-cta p {
		max-width: 36rem;
		margin: 1.8rem 0 0;
		color: var(--landing-muted);
		font-size: 1.125rem;
		line-height: 1.7;
		text-wrap: pretty;
	}

	.final-download {
		margin-top: 2.2rem;
		padding: 0 1.45rem;
		background: var(--landing-gold);
		color: oklch(0.12 0.016 88);
		font-size: 0.875rem;
		font-weight: 650;
	}

	.final-aperture {
		position: absolute;
		top: 50%;
		right: -11%;
		z-index: 1;
		width: min(68vw, 62rem);
		opacity: 0.3;
		pointer-events: none;
		translate: 0 -50%;
		-webkit-mask-image: linear-gradient(90deg, transparent, #000 32%);
		mask-image: linear-gradient(90deg, transparent, #000 32%);
	}

	.final-glow {
		position: absolute;
		top: 50%;
		right: 2%;
		z-index: 0;
		width: min(42rem, 48vw);
		aspect-ratio: 1;
		border-radius: 50%;
		background: oklch(0.55 0.22 258 / 0.22);
		filter: blur(5rem);
		pointer-events: none;
		translate: 0 -50%;
	}

	.site-footer {
		border-top: 1px solid oklch(0.35 0.026 258 / 0.6);
		background: oklch(0.045 0.004 258);
	}

	.site-footer > div > div:first-child {
		max-width: 47rem;
	}

	.footer-brand {
		color: var(--landing-gold);
		font-size: 0.875rem;
		font-weight: 650;
		letter-spacing: 0.2em;
		text-decoration: none;
	}

	.site-footer p {
		margin: 1rem 0 0;
		color: oklch(0.64 0.014 258);
		font-size: 1rem;
		line-height: 1.6;
	}

	.footer-links {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem 1.2rem;
	}

	.footer-links a {
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		color: oklch(0.77 0.014 258);
		font-size: 0.875rem;
		text-decoration: none;
		transition: color 180ms var(--ease-out-quart);
	}

	.footer-links a:hover {
		color: var(--landing-ink);
	}

	@media (min-width: 64rem) {
		.manifesto-grid {
			grid-template-columns: minmax(25rem, 0.82fr) minmax(32rem, 1.18fr);
			grid-template-rows: auto auto;
			column-gap: clamp(3rem, 6vw, 6rem);
			row-gap: clamp(2.25rem, 4vw, 3.75rem);
		}

		.manifesto h2 {
			grid-column: 1;
			grid-row: 1;
		}

		.manifesto-copy {
			grid-column: 1;
			grid-row: 2;
			max-width: 31rem;
			padding-top: 0;
		}

		.showcase-heading,
		.journey-heading {
			grid-template-columns: minmax(0, 1.1fr) minmax(22rem, 0.9fr);
		}
	}

	@media (max-width: 63.99rem) {
		.hero {
			padding-top: 2rem;
		}

		.hero-copy {
			max-width: 46rem;
		}

		.hero-visual {
			min-height: 42rem;
		}

		.aperture-rotator {
			width: min(44rem, 94vw);
		}

		.hero-visual :global(.hero-device) {
			width: min(18rem, 49vw);
			margin-left: 8%;
		}

		.journey-material {
			opacity: 0.48;
		}

		.manifesto-vault {
			position: relative;
			top: auto;
			right: auto;
			left: auto;
			width: min(62rem, 120vw);
			margin: -2rem -12vw -5rem auto;
			translate: 0 0;
		}

		.manifesto-copy {
			max-width: 34rem;
		}

		.showcase-layout {
			display: block;
		}

		.showcase-step {
			min-height: auto;
			padding: 3.75rem 0 4.75rem;
			opacity: 1;
		}

		.showcase-step__signal {
			display: none;
		}

		.showcase-mobile-device {
			display: grid;
			place-items: center;
			margin-top: 2.25rem;
		}

		.showcase-mobile-device :global(.device) {
			width: min(18rem, 72vw);
		}

		.showcase-stage {
			display: none;
		}

		.privacy-visual {
			order: 2;
			min-height: 44rem;
		}

		.privacy-copy {
			order: 1;
		}
	}

	@media (max-width: 47.99rem) {
		.hero > div:nth-child(2) {
			padding-top: 8rem;
		}

		h1 {
			font-size: clamp(3rem, 15vw, 4.8rem);
		}

		.hero-body {
			margin-top: 1.5rem;
		}

		.hero-actions {
			align-items: stretch;
			flex-direction: column;
		}

		.primary-cta,
		.secondary-cta {
			width: 100%;
			min-height: 3.25rem;
		}

		.hero-visual {
			min-height: 38rem;
			margin-top: 1.5rem;
		}

		.aperture-rotator {
			width: 37rem;
			max-width: 126vw;
		}

		.hero-visual :global(.hero-device) {
			width: min(16.5rem, 66vw);
			margin-left: 2%;
		}

		.hero-metal--ring {
			right: -10%;
			bottom: 9%;
		}

		.scroll-cue {
			display: none;
		}

		.manifesto {
			min-height: 70vh;
		}

		.manifesto h2,
		.showcase-heading h2,
		.journey h2,
		.privacy-section h2 {
			font-size: clamp(2.45rem, 11vw, 3.65rem);
		}

		.manifesto-vault {
			width: 54rem;
			max-width: none;
			margin: -2rem 0 -5rem -17.25rem;
		}

		.manifesto-vault__device {
			width: 8.25rem;
		}

		.showcase {
			padding-block: 7rem;
		}

		.showcase-step {
			padding-block: 3.5rem 4.5rem;
		}

		.showcase-step:nth-child(odd) .showcase-mobile-device {
			justify-items: start;
		}

		.showcase-step:nth-child(even) .showcase-mobile-device {
			justify-items: end;
		}

		.showcase-step:nth-child(even) .showcase-mobile-device :global(.device) {
			width: min(17rem, 68vw);
		}

		.showcase-step h3 {
			font-size: clamp(2rem, 9vw, 2.75rem);
		}

		.journey-material {
			right: -66%;
			bottom: 10%;
			width: 150vw;
		}

		.journey-steps {
			display: flex;
			flex-direction: column;
			gap: 0;
			margin-top: 4rem;
			padding-left: 1.4rem;
		}

		.journey-line {
			top: 0;
			bottom: 0;
			left: 0.28rem;
			width: 1px;
			height: auto;
		}

		.journey-progress {
			width: 100%;
			height: 100%;
			transform: none !important;
			transform-origin: top;
		}

		.journey-step {
			position: relative;
			padding: 0 0 3rem 1.3rem;
		}

		.journey-step > span {
			top: 0.35rem;
			left: -1.39rem;
		}

		.privacy-visual {
			min-height: 38rem;
		}

		.privacy-visual :global(.privacy-device) {
			width: min(16rem, 64vw);
		}

		.privacy-node--phone {
			top: 14%;
			left: -2%;
		}

		.privacy-node--cloud {
			right: -2%;
			bottom: 18%;
		}

		.privacy-node--server {
			top: 10%;
		}

		.privacy-connector {
			display: none;
		}

		.sensitive-demo {
			padding: 1.15rem;
		}

		.final-cta {
			min-height: 76vh;
		}

		.final-cta h2 {
			font-size: clamp(3rem, 14vw, 4.6rem);
		}

		.final-aperture {
			right: -19rem;
			width: 48rem;
		}

		.final-glow {
			right: -14rem;
			width: 34rem;
		}

		.final-download {
			width: 100%;
			min-height: 3.25rem;
		}
	}

	@media (max-width: 23rem) {
		.hero-visual {
			min-height: 34rem;
		}

		.manifesto-vault {
			margin-left: -18.5rem;
		}

		.privacy-node {
			font-size: 0.75rem;
		}
	}

	@media (hover: hover) and (pointer: fine) {
		.showcase-dots button:hover::after {
			background: var(--landing-gold);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.kara-landing *,
		.kara-landing *::before,
		.kara-landing *::after {
			scroll-behavior: auto !important;
			animation-duration: 0.01ms !important;
			animation-iteration-count: 1 !important;
			transition-duration: 0.01ms !important;
		}

		.metal-ticker__track {
			transform: translateX(-1rem);
		}

		.journey-progress {
			transform: none !important;
		}
	}
</style>
