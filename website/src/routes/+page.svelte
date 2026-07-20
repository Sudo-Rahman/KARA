<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import SiteFooter from '$lib/components/SiteFooter.svelte';
	import SiteHeader from '$lib/components/SiteHeader.svelte';
	import StoreLinks from '$lib/components/StoreLinks.svelte';
	import ThreeScene from '$lib/components/ThreeScene.svelte';
	import InventoryMockup from '$lib/components/landing/InventoryMockup.svelte';
	import PortfolioMockup from '$lib/components/landing/PortfolioMockup.svelte';
	import PrivacyDiagram from '$lib/components/landing/PrivacyDiagram.svelte';
	import ReportMockup from '$lib/components/landing/ReportMockup.svelte';
	import SimulationMockup from '$lib/components/landing/SimulationMockup.svelte';
	import { publicConfig } from '$lib/config';
	import { normalizeLocalizedHref } from '$lib/localized-href';
	import { m } from '$lib/paraglide/messages';
	import { getLocale, localizeHref } from '$lib/paraglide/runtime';
	import type { SceneReadyDetail, SceneQuality } from '$lib/three/types';

	let story: HTMLElement;
	let storyProgress = $state(0);
	let sceneReady = $state(false);
	let sceneQuality = $state<SceneQuality | 'loading'>('loading');
	const locale = $derived(getLocale());
	const origin = $derived(publicConfig.siteUrl ?? page.url.origin);
	const canonical = $derived(new URL(normalizeLocalizedHref(localizeHref('/', { locale })), origin).href);
	const frenchUrl = $derived(new URL(normalizeLocalizedHref(localizeHref('/', { locale: 'fr' })), origin).href);
	const englishUrl = $derived(new URL(normalizeLocalizedHref(localizeHref('/', { locale: 'en' })), origin).href);
	const socialImage = $derived(new URL('/brand/kara-og.png', origin).href);
	const hasStoreRelease = $derived(Boolean(publicConfig.appStoreUrl || publicConfig.googlePlayUrl));
	const structuredData = $derived(
		JSON.stringify({
			'@context': 'https://schema.org',
			'@type': 'SoftwareApplication',
			name: 'Kara',
			applicationCategory: 'FinanceApplication',
			operatingSystem: 'iOS, Android',
			description: m.meta_description(),
			url: canonical,
			downloadUrl: [publicConfig.appStoreUrl, publicConfig.googlePlayUrl].filter(Boolean)
		})
	);

	onMount(() => {
		let cleanup: () => void = () => undefined;
		let disposed = false;
		let progressFrame: number | null = null;
		let animationsStarted = false;
		const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
		const saveData =
			(navigator as Navigator & { connection?: { saveData?: boolean } }).connection?.saveData === true;

		const updateStoryProgress = () => {
			progressFrame = null;
			const maximumScroll = Math.max(1, story.scrollHeight - window.innerHeight);
			storyProgress = Math.min(1, Math.max(0, (window.scrollY - story.offsetTop) / maximumScroll));
		};

		if (reducedMotion || saveData) {
			return () => {
				disposed = true;
			};
		}

		const startAnimations = () => {
			if (animationsStarted || disposed) return;
			animationsStarted = true;

			void Promise.all([import('gsap'), import('gsap/ScrollTrigger')]).then(
				([gsapModule, scrollModule]) => {
					if (disposed) return;
					const gsap = gsapModule.gsap;
					const ScrollTrigger = scrollModule.ScrollTrigger;
					gsap.registerPlugin(ScrollTrigger);

					const context = gsap.context(() => {
						gsap.fromTo(
							'[data-hero-copy]',
							{ yPercent: 0 },
							{ yPercent: -4, ease: 'none', scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true } }
						);

						gsap.fromTo(
							'[data-inventory-ui]',
							{ y: 72, rotateX: 7, transformPerspective: 900 },
							{ y: -18, rotateX: 0, ease: 'none', scrollTrigger: { trigger: '#inventory', start: 'top 82%', end: 'bottom 38%', scrub: 0.5 } }
						);

						gsap.fromTo(
							'[data-portfolio-ui]',
							{ clipPath: 'inset(0 34% 0 34%)', scale: 0.94 },
							{ clipPath: 'inset(0 0% 0 0%)', scale: 1, ease: 'none', scrollTrigger: { trigger: '#insights', start: 'top 80%', end: 'center 55%', scrub: 0.5 } }
						);

						gsap.fromTo(
							'[data-simulation-ui]',
							{ xPercent: 8, rotateY: -7, transformPerspective: 1000 },
							{ xPercent: -2, rotateY: 0, ease: 'none', scrollTrigger: { trigger: '#simulation', start: 'top 78%', end: 'bottom 38%', scrub: 0.5 } }
						);

						gsap.fromTo(
							'[data-report-ui]',
							{ rotateZ: -2.5, y: 56 },
							{ rotateZ: 0.5, y: -14, ease: 'none', scrollTrigger: { trigger: '#report', start: 'top 82%', end: 'bottom 38%', scrub: 0.5 } }
						);

						gsap.fromTo(
							'[data-privacy-ui]',
							{ '--privacy-reveal': 0 },
							{ '--privacy-reveal': 1, ease: 'none', scrollTrigger: { trigger: '#privacy', start: 'top 75%', end: 'center 42%', scrub: 0.4 } }
						);

						gsap.utils.toArray<HTMLElement>('[data-chapter-copy]').forEach((element) => {
							gsap.fromTo(
								element,
								{ y: 28 },
								{ y: -8, ease: 'none', scrollTrigger: { trigger: element, start: 'top 84%', end: 'bottom 42%', scrub: 0.35 } }
							);
						});
					});

					cleanup = () => context.revert();
				}
			);
		};

		const handleScroll = () => {
			if (progressFrame === null) progressFrame = requestAnimationFrame(updateStoryProgress);
			startAnimations();
		};

		updateStoryProgress();
		window.addEventListener('scroll', handleScroll, { passive: true });
		if (window.scrollY > 0) startAnimations();

		return () => {
			disposed = true;
			if (progressFrame !== null) cancelAnimationFrame(progressFrame);
			window.removeEventListener('scroll', handleScroll);
			cleanup();
		};
	});
</script>

<svelte:head>
	<title>{m.meta_title()}</title>
	<meta name="description" content={m.meta_description()} />
	<link rel="canonical" href={canonical} />
	<link rel="alternate" hreflang="fr" href={frenchUrl} />
	<link rel="alternate" hreflang="en" href={englishUrl} />
	<link rel="alternate" hreflang="x-default" href={frenchUrl} />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="Kara" />
	<meta property="og:title" content={m.meta_title()} />
	<meta property="og:description" content={m.meta_description()} />
	<meta property="og:url" content={canonical} />
	<meta property="og:image" content={socialImage} />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content={m.meta_title()} />
	<meta property="og:locale" content={locale === 'fr' ? 'fr_FR' : 'en_US'} />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content={m.meta_title()} />
	<meta name="twitter:description" content={m.meta_description()} />
	<meta name="twitter:image" content={socialImage} />
	<script type="application/ld+json">{structuredData}</script>
</svelte:head>

<SiteHeader />

<main
	id="main-content"
	bind:this={story}
	class:scene-ready={sceneReady}
	class:scene-static={sceneQuality === 'static'}
	tabindex="-1"
>
	<div class="scene-layer" aria-hidden="true">
		{#key locale}
			<ThreeScene
				progress={storyProgress}
				onready={(detail: SceneReadyDetail) => {
					sceneQuality = detail.quality;
					sceneReady = detail.quality !== 'static';
				}}
				onerror={() => {
					sceneQuality = 'static';
					sceneReady = false;
				}}
			/>
		{/key}
	</div>

	<section class="hero" aria-labelledby="hero-title">
		<div class="site-container hero-grid">
			<div class="hero-copy" data-hero-copy>
				<p class="trust-line"><span></span>{m.hero_proof()}</p>
				<h1 id="hero-title"><span>{m.hero_title_first()}</span><span>{m.hero_title_second()}</span></h1>
				<p class="hero-body">{m.hero_body()}</p>
				<div class="hero-stores">
					<StoreLinks showQr={false} />
				</div>
				<p class="availability">{hasStoreRelease ? m.hero_note() : m.hero_note_soon()}</p>
			</div>
			<div class="hero-object-space" aria-hidden="true"></div>
		</div>
		<div class="scroll-cue" aria-hidden="true"><span></span>{m.scroll_label()}</div>
	</section>

	<section id="inventory" class="chapter chapter-inventory" aria-labelledby="inventory-title">
		<div class="site-container chapter-grid">
			<div class="chapter-copy" data-chapter-copy>
				<h2 id="inventory-title">{m.inventory_title()}</h2>
				<p>{m.inventory_body()}</p>
				<p class="chapter-note">{m.inventory_detail()}</p>
			</div>
			<div class="mockup-stage inventory-stage" data-inventory-ui>
				<InventoryMockup />
			</div>
		</div>
	</section>

	<section id="insights" class="chapter chapter-insights" aria-labelledby="insights-title">
		<div class="site-container chapter-grid chapter-grid-reverse">
			<div class="mockup-stage portfolio-stage" data-portfolio-ui>
				<PortfolioMockup />
			</div>
			<div class="chapter-copy" data-chapter-copy>
				<h2 id="insights-title">{m.overview_title()}</h2>
				<p>{m.overview_body()}</p>
				<p class="chapter-note">{m.overview_note()}</p>
			</div>
		</div>
	</section>

	<section id="simulation" class="chapter chapter-simulation" aria-labelledby="simulation-title">
		<div class="site-container chapter-grid">
			<div class="chapter-copy" data-chapter-copy>
				<h2 id="simulation-title">{m.simulation_title()}</h2>
				<p>{m.simulation_body()}</p>
				<p class="chapter-note disclaimer">{m.simulation_disclaimer()}</p>
			</div>
			<div class="mockup-stage simulation-stage" data-simulation-ui>
				<SimulationMockup />
			</div>
		</div>
	</section>

	<section id="report" class="chapter chapter-report" aria-labelledby="report-title">
		<div class="site-container chapter-grid chapter-grid-reverse">
			<div class="mockup-stage report-stage" data-report-ui>
				<ReportMockup />
			</div>
			<div class="chapter-copy" data-chapter-copy>
				<h2 id="report-title">{m.report_title()}</h2>
				<p>{m.report_body()}</p>
				<p class="chapter-note">{m.report_note()}</p>
			</div>
		</div>
	</section>

	<section id="privacy" class="chapter chapter-privacy" aria-labelledby="privacy-title">
		<div class="privacy-glow" aria-hidden="true"></div>
		<div class="site-container privacy-layout">
			<div class="chapter-copy privacy-copy" data-chapter-copy>
				<h2 id="privacy-title">{m.privacy_title()}</h2>
				<p>{m.privacy_body()}</p>
				<p class="chapter-note">{m.privacy_note()}</p>
			</div>
			<div class="privacy-stage" data-privacy-ui>
				<PrivacyDiagram />
			</div>
		</div>
	</section>

	<section id="download" class="download-section" aria-labelledby="download-title">
		<div class="download-aura" aria-hidden="true"></div>
		<div class="site-container download-content">
			<h2 id="download-title">{m.download_title()}</h2>
			<p>{m.download_body()}</p>
			<div class="download-stores"><StoreLinks /></div>
			<p class="download-note">{m.download_note()}</p>
		</div>
	</section>
</main>

<SiteFooter />

<style>
	main {
		position: relative;
		isolation: isolate;
		overflow: clip;
		background: var(--color-void);
	}

	.scene-layer {
		position: fixed;
		z-index: 0;
		inset: 0;
		pointer-events: none;
	}

	.scene-static .scene-layer {
		position: absolute;
		height: 100svh;
	}

	.hero,
	.chapter,
	.download-section {
		position: relative;
		z-index: 2;
	}

	.chapter,
	.download-section {
		scroll-margin-top: 5.25rem;
	}

	.hero {
		min-height: max(55rem, 138svh);
		padding-top: max(7rem, calc(6rem + env(safe-area-inset-top)));
	}

	.hero-grid {
		display: grid;
		grid-template-columns: minmax(0, 0.92fr) minmax(20rem, 1.08fr);
		align-items: start;
		min-height: 100svh;
		padding-top: clamp(4rem, 10vh, 8rem);
	}

	.hero-copy {
		position: relative;
		z-index: 3;
		max-width: 46rem;
	}

	.hero-copy::before,
	.chapter-copy::before,
	.download-content::before {
		position: absolute;
		z-index: -1;
		inset: -3rem -4rem;
		background: radial-gradient(ellipse at center, var(--color-void) 0 48%, transparent 76%);
		content: '';
		pointer-events: none;
	}

	.trust-line,
	.availability,
	.scroll-cue,
	.chapter-note,
	.download-note {
		color: var(--color-muted);
		font-size: 0.78rem;
	}

	.trust-line {
		display: flex;
		align-items: center;
		gap: 0.7rem;
		margin-bottom: clamp(1.5rem, 4vh, 2.5rem);
	}

	.trust-line span {
		width: 0.46rem;
		height: 0.46rem;
		border-radius: 50%;
		background: var(--color-positive);
		box-shadow: 0 0 1rem oklch(0.76 0.13 153 / 0.58);
	}

	h1 {
		max-width: 12ch;
		font-size: var(--text-display);
		font-weight: 430;
		letter-spacing: -0.04em;
		line-height: 0.92;
	}

	h1 span {
		display: block;
	}

	h1 span:last-child {
		color: var(--color-gold-bright);
	}

	.hero-body {
		max-width: 37rem;
		margin-top: clamp(1.5rem, 4vh, 2.5rem);
		color: oklch(0.8 0.012 258);
		font-size: clamp(1rem, 1.4vw, 1.2rem);
		line-height: 1.65;
	}

	.hero-stores {
		max-width: 30rem;
		margin-top: 2rem;
	}

	.availability {
		margin-top: 0.85rem;
	}

	.scroll-cue {
		position: absolute;
		left: var(--page-gutter);
		bottom: 12vh;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		writing-mode: vertical-rl;
	}

	.scroll-cue span {
		width: 1px;
		height: 3.5rem;
		background: linear-gradient(var(--color-cobalt-bright), transparent);
	}

	.chapter {
		display: flex;
		align-items: center;
		min-height: max(48rem, 118svh);
		padding-block: clamp(6rem, 14vh, 10rem);
	}

	.chapter-grid {
		display: grid;
		grid-template-columns: minmax(17rem, 0.78fr) minmax(25rem, 1.22fr);
		align-items: center;
		gap: clamp(3rem, 8vw, 8rem);
	}

	.chapter-grid-reverse {
		grid-template-columns: minmax(25rem, 1.22fr) minmax(17rem, 0.78fr);
	}

	.chapter-copy {
		position: relative;
		z-index: 4;
		max-width: 36rem;
	}

	.chapter-copy h2,
	.download-content h2 {
		font-size: var(--text-section);
		font-weight: 430;
		letter-spacing: -0.04em;
		line-height: 0.98;
	}

	.chapter-copy > p:not(.chapter-note) {
		max-width: 34rem;
		margin-top: 1.5rem;
		color: oklch(0.79 0.012 258);
		font-size: clamp(1rem, 1.4vw, 1.15rem);
		line-height: 1.7;
	}

	.chapter-note {
		max-width: 31rem;
		margin-top: 1.15rem;
		padding-top: 1.15rem;
		border-top: 1px solid var(--color-line);
		line-height: 1.6;
	}

	.disclaimer {
		color: oklch(0.64 0.015 258);
		font-size: 0.9rem;
		line-height: 1.65;
	}

	.mockup-stage,
	.privacy-stage {
		position: relative;
		z-index: 5;
		min-width: 0;
	}

	.inventory-stage,
	.simulation-stage {
		display: flex;
		justify-content: end;
	}

	.portfolio-stage,
	.report-stage {
		display: flex;
		justify-content: start;
	}

	.chapter-inventory::before,
	.chapter-simulation::before {
		content: '';
		position: absolute;
		z-index: -1;
		width: 60vw;
		height: 60vw;
		border-radius: 50%;
		background: radial-gradient(circle, oklch(0.38 0.12 258 / 0.18), transparent 66%);
		filter: blur(3rem);
		pointer-events: none;
	}

	.chapter-inventory::before { right: -20vw; top: 10%; }
	.chapter-simulation::before { left: -26vw; top: 12%; }

	.chapter-report {
		background: linear-gradient(to bottom, transparent, oklch(0.1 0.008 258 / 0.9) 45%, transparent);
	}

	.chapter-privacy {
		min-height: max(56rem, 132svh);
		isolation: isolate;
	}

	.privacy-glow {
		position: absolute;
		z-index: -1;
		inset: 5% -20%;
		background: radial-gradient(ellipse at center, oklch(0.31 0.13 258 / 0.56), transparent 68%);
		filter: blur(3rem);
	}

	.privacy-layout {
		display: grid;
		grid-template-columns: minmax(0, 0.78fr) minmax(28rem, 1.22fr);
		align-items: center;
		gap: clamp(3rem, 7vw, 7rem);
	}

	.privacy-copy h2 {
		max-width: 13ch;
	}

	.privacy-stage {
		opacity: calc(0.8 + var(--privacy-reveal, 1) * 0.2);
		transform: scale(calc(0.96 + var(--privacy-reveal, 1) * 0.04));
	}

	.download-section {
		display: grid;
		min-height: max(54rem, 116svh);
		place-items: center;
		padding-block: clamp(8rem, 18vh, 12rem);
		isolation: isolate;
	}

	.download-aura {
		position: absolute;
		z-index: -1;
		left: 50%;
		top: 48%;
		width: min(92vw, 72rem);
		aspect-ratio: 1.5;
		border-radius: 50%;
		background: radial-gradient(ellipse, oklch(0.48 0.17 258 / 0.34), oklch(0.24 0.1 258 / 0.12) 45%, transparent 70%);
		filter: blur(2rem);
		transform: translate(-50%, -50%);
	}

	.download-content {
		position: relative;
		z-index: 6;
		display: flex;
		align-items: center;
		flex-direction: column;
		text-align: center;
	}

	.download-content h2 {
		max-width: 12ch;
	}

	.download-content > p:not(.download-note) {
		max-width: 38rem;
		margin-top: 1.5rem;
		color: oklch(0.8 0.012 258);
		font-size: 1.05rem;
	}

	.download-stores {
		width: min(100%, 31rem);
		margin-top: 2.5rem;
	}

	.download-stores :global(.store-links) {
		justify-content: center;
	}

	.download-note {
		margin-top: 1.5rem;
	}

	@media (max-width: 63.99rem) {
		.hero {
			min-height: max(56rem, 128svh);
		}

		.hero-grid {
			grid-template-columns: minmax(0, 1fr) minmax(14rem, 0.58fr);
		}

		.chapter-grid,
		.chapter-grid-reverse,
		.privacy-layout {
			grid-template-columns: minmax(0, 1fr) minmax(22rem, 1.05fr);
			gap: clamp(2rem, 5vw, 4rem);
		}

		.chapter-grid-reverse .chapter-copy {
			order: -1;
		}
	}

	@media (max-width: 47.99rem) {
		.scene-static .scene-layer {
			height: max(64rem, 132svh);
		}

		.scene-static :global(.kara-three-scene__halo),
		.scene-static :global(.kara-three-scene__vault),
		.scene-static :global(.kara-three-scene__bar) {
			top: 84%;
		}

		.hero {
			min-height: max(52rem, 132svh);
			padding-top: max(5.25rem, calc(4.5rem + env(safe-area-inset-top)));
		}

		.hero-grid {
			grid-template-columns: 1fr;
			align-items: start;
			min-height: 100svh;
			padding-top: clamp(2.5rem, 8vh, 5rem);
		}

		.hero-copy {
			max-width: 35rem;
			background: var(--color-void);
			box-shadow: 0 0 1.75rem 1.25rem var(--color-void);
		}

		.hero-body {
			max-width: 31rem;
		}

		.hero-object-space {
			min-height: 50svh;
		}

		.hero-stores {
			max-width: 20rem;
		}

		.scroll-cue {
			display: none;
		}

		.chapter {
			min-height: auto;
			padding-block: clamp(6rem, 15vh, 9rem);
		}

		.chapter-grid,
		.chapter-grid-reverse,
		.privacy-layout {
			grid-template-columns: minmax(0, 1fr);
			gap: 3.25rem;
		}

		.chapter-grid-reverse .chapter-copy {
			order: 0;
		}

		.chapter-grid-reverse .mockup-stage {
			order: 1;
		}

		.mockup-stage,
		.privacy-stage,
		.inventory-stage,
		.simulation-stage,
		.portfolio-stage,
		.report-stage {
			justify-content: center;
			width: 100%;
		}

		.chapter-copy {
			max-width: 40rem;
		}

		.chapter-privacy {
			min-height: auto;
			padding-block: 8rem;
		}

		.download-section {
			min-height: 58rem;
			padding-bottom: max(7rem, env(safe-area-inset-bottom));
		}
	}

	@media (max-width: 30rem) {
		.trust-line {
			font-size: 0.72rem;
		}

		.hero-stores :global(.store-links) {
			gap: 0.75rem;
		}

		.hero-stores :global(.store-option) {
			flex-basis: 9.75rem;
		}

	}

	@media (max-height: 35rem) and (orientation: landscape) {
		.hero {
			min-height: 44rem;
		}

		.hero-grid {
			grid-template-columns: minmax(0, 0.92fr) minmax(15rem, 1.08fr);
			padding-top: 2rem;
		}

		.hero-object-space {
			min-height: 0;
		}

		.chapter {
			padding-block: 5rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.scene-layer {
			position: absolute;
			height: 100svh;
		}

		[data-hero-copy],
		[data-inventory-ui],
		[data-portfolio-ui],
		[data-simulation-ui],
		[data-report-ui],
		[data-privacy-ui],
		[data-chapter-copy] {
			opacity: 1 !important;
			filter: none !important;
			clip-path: none !important;
			transform: none !important;
		}
	}

	@media (prefers-reduced-motion: reduce) and (max-width: 47.99rem) {
		.scene-layer {
			height: max(64rem, 132svh);
		}

		:global(.kara-three-scene__halo),
		:global(.kara-three-scene__vault),
		:global(.kara-three-scene__bar) {
			top: 84%;
		}
	}
</style>
