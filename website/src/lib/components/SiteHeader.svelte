<script lang="ts">
	import { onMount } from 'svelte';
	import type { Pathname } from '$app/types';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import AppleIcon from '@lucide/svelte/icons/apple';
	import ArrowRightIcon from '@lucide/svelte/icons/arrow-right';
	import { publicConfig } from '$lib/config';
	import { normalizeLocalizedHref } from '$lib/localized-href';
	import { getLocale, localizeHref } from '$lib/paraglide/runtime';

	let {
		mode = 'overlay'
	}: {
		mode?: 'overlay' | 'sticky';
	} = $props();

	const copyByLocale = {
		fr: {
			experience: 'Expérience',
			privacy: 'Confidentialité',
			support: 'Assistance',
			download: 'Télécharger',
			explore: 'Voir l’expérience',
			homeLabel: 'Kara — accueil',
			navLabel: 'Navigation principale',
			languageLabel: 'Afficher le site en anglais'
		},
		en: {
			experience: 'Experience',
			privacy: 'Privacy',
			support: 'Support',
			download: 'Download',
			explore: 'See the experience',
			homeLabel: 'Kara — home',
			navLabel: 'Main navigation',
			languageLabel: 'Show the site in French'
		}
	} satisfies Record<
		'fr' | 'en',
		{
			experience: string;
			privacy: string;
			support: string;
			download: string;
			explore: string;
			homeLabel: string;
			navLabel: string;
			languageLabel: string;
		}
	>;

	const locale = $derived(getLocale() === 'fr' ? 'fr' : 'en');
	const copy = $derived(copyByLocale[locale]);
	const alternativeLocale = $derived(locale === 'fr' ? 'en' : 'fr');
	const homeHref = $derived(
		resolve(normalizeLocalizedHref(localizeHref('/', { locale })) as Pathname)
	);
	const experienceHref = $derived(
		resolve(normalizeLocalizedHref(localizeHref('/#experience', { locale })) as Pathname)
	);
	const privacyHref = $derived(
		resolve(normalizeLocalizedHref(localizeHref('/privacy', { locale })) as Pathname)
	);
	const supportHref = $derived(
		resolve(normalizeLocalizedHref(localizeHref('/support', { locale })) as Pathname)
	);
	const alternativeHref = $derived(
		resolve(
			normalizeLocalizedHref(
				localizeHref(`${page.url.pathname}${page.url.hash}`, { locale: alternativeLocale })
			) as Pathname
		)
	);
	const isPrivacyPage = $derived(page.url.pathname.endsWith('/privacy'));
	const isSupportPage = $derived(page.url.pathname.endsWith('/support'));
	const appStoreHref = publicConfig.appStoreUrl;

	let scrolled = $state(false);
	const elevated = $derived(mode === 'sticky' || scrolled);

	onMount(() => {
		if (mode === 'sticky') return;

		const updateElevation = () => {
			scrolled = window.scrollY > 24;
		};

		updateElevation();
		window.addEventListener('scroll', updateElevation, { passive: true });

		return () => window.removeEventListener('scroll', updateElevation);
	});
</script>

<header class:elevated class:overlay={mode === 'overlay'} class:sticky={mode === 'sticky'} class="site-header">
	<div class="nav-shell">
		<a class="brand-link" href={homeHref} aria-label={copy.homeLabel}>
			<img src="/brand/kara-app-icon-96.webp" alt="" width="36" height="36" />
			<span>KARA</span>
		</a>

		<nav aria-label={copy.navLabel}>
			<a href={experienceHref}>{copy.experience}</a>
			<a href={privacyHref} aria-current={isPrivacyPage ? 'page' : undefined}>{copy.privacy}</a>
			<a href={supportHref} aria-current={isSupportPage ? 'page' : undefined}>{copy.support}</a>
		</nav>

		<div class="actions">
			<a
				class="locale-link"
				href={alternativeHref}
				data-sveltekit-reload
				hreflang={alternativeLocale}
				lang={alternativeLocale}
				aria-label={copy.languageLabel}
			>
				{alternativeLocale.toUpperCase()}
			</a>

			{#if appStoreHref}
				<a class="download-link" href={appStoreHref} target="_blank" rel="noreferrer">
					<AppleIcon size={18} strokeWidth={1.8} aria-hidden="true" />
					<span>{copy.download}</span>
				</a>
			{:else}
				<a class="download-link" href={experienceHref}>
					<ArrowRightIcon size={18} strokeWidth={1.8} aria-hidden="true" />
					<span>{copy.explore}</span>
				</a>
			{/if}
		</div>
	</div>
</header>

<style>
	.site-header {
		top: 0;
		left: 0;
		z-index: 40;
		width: 100%;
		padding-top: env(safe-area-inset-top, 0px);
		border-bottom: 1px solid transparent;
		color: var(--color-ink, oklch(0.965 0.006 95));
		animation: header-reveal 600ms var(--ease-out-expo, cubic-bezier(0.16, 1, 0.3, 1)) both;
		transition:
			border-color 260ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1)),
			background-color 260ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1)),
			backdrop-filter 260ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1));
	}

	.site-header.overlay {
		position: fixed;
		background: linear-gradient(to bottom, oklch(0.045 0.004 258 / 0.72), transparent);
	}

	.site-header.sticky {
		position: sticky;
	}

	.site-header.elevated {
		border-bottom-color: oklch(0.35 0.026 258 / 0.54);
		background: oklch(0.055 0.008 258 / 0.86);
		backdrop-filter: blur(18px) saturate(130%);
	}

	.nav-shell {
		display: grid;
		width: min(100%, 90rem);
		min-height: 5.25rem;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		gap: clamp(1.25rem, 3vw, 3rem);
		margin-inline: auto;
		padding-right: max(clamp(1rem, 3.35vw, 3rem), env(safe-area-inset-right, 0px));
		padding-left: max(clamp(1rem, 3.35vw, 3rem), env(safe-area-inset-left, 0px));
	}

	.brand-link {
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		gap: 0.75rem;
		color: oklch(0.86 0.12 92);
		font-size: 0.875rem;
		font-weight: 650;
		letter-spacing: 0.22em;
		text-decoration: none;
	}

	.brand-link img {
		width: 2rem;
		height: 2rem;
		border-radius: 0.55rem;
		transition:
			transform 260ms var(--ease-out-expo, cubic-bezier(0.16, 1, 0.3, 1)),
			filter 260ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1));
	}

	.brand-link:hover img {
		filter: drop-shadow(0 0 0.8rem oklch(0.86 0.12 92 / 0.32));
		transform: rotate(-4deg) scale(1.05);
	}

	nav {
		display: flex;
		justify-content: center;
		gap: clamp(1.25rem, 2.6vw, 2.5rem);
	}

	nav a,
	.locale-link {
		position: relative;
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		color: oklch(0.84 0.014 258);
		font-size: 0.875rem;
		font-weight: 460;
		text-decoration: none;
		transition: color 180ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1));
	}

	nav a::after {
		position: absolute;
		right: 0;
		bottom: 0.28rem;
		left: 0;
		height: 1px;
		background: oklch(0.86 0.12 92);
		content: '';
		transform: scaleX(0);
		transform-origin: right;
		transition: transform 240ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1));
	}

	nav a:hover,
	nav a[aria-current='page'],
	.locale-link:hover {
		color: var(--color-ink, oklch(0.965 0.006 95));
	}

	nav a:hover::after,
	nav a[aria-current='page']::after {
		transform: scaleX(1);
		transform-origin: left;
	}

	.actions {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.download-link {
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		justify-content: center;
		gap: 0.65rem;
		padding: 0 1.05rem;
		border-radius: 999px;
		background: oklch(0.86 0.12 92);
		color: oklch(0.13 0.018 88);
		font-size: 0.875rem;
		font-weight: 650;
		text-decoration: none;
		transition:
			transform 180ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1)),
			background-color 180ms var(--ease-out-quart, cubic-bezier(0.25, 1, 0.5, 1));
	}

	.download-link:hover {
		background: oklch(0.91 0.1 96);
		transform: translateY(-2px);
	}

	.download-link:active {
		transform: translateY(0) scale(0.98);
	}

	:where(a):focus-visible {
		outline: 2px solid var(--color-cobalt-bright, oklch(0.72 0.15 258));
		outline-offset: 4px;
	}

	@keyframes header-reveal {
		from {
			opacity: 0;
			transform: translateY(-1rem);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@media (max-width: 56rem) {
		nav {
			display: none;
		}

		.nav-shell {
			grid-template-columns: auto 1fr;
			min-height: 4.75rem;
		}

		.actions {
			justify-content: end;
		}
	}

	@media (max-width: 32rem) {
		.actions {
			gap: 0.6rem;
		}

		.download-link {
			width: 2.75rem;
			padding: 0;
		}

		.download-link span {
			position: absolute;
			width: 1px;
			height: 1px;
			overflow: hidden;
			clip: rect(0, 0, 0, 0);
		}
	}

	@media (max-width: 23rem) {
		.brand-link {
			gap: 0.6rem;
			font-size: 0.75rem;
		}

		.brand-link img {
			width: 1.75rem;
			height: 1.75rem;
		}

		.locale-link {
			font-size: 0.75rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.site-header {
			animation: none;
			transition: none;
		}

		.brand-link img,
		nav a,
		.locale-link,
		.download-link {
			transition: none;
		}
	}

	@media print {
		.site-header {
			display: none;
		}
	}
</style>
