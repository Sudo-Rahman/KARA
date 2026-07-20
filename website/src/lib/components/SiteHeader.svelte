<script lang="ts">
	import type { Pathname } from '$app/types';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import ArrowDownToLine from '@lucide/svelte/icons/arrow-down-to-line';
	import Languages from '@lucide/svelte/icons/languages';
	import { m } from '$lib/paraglide/messages';
	import { normalizeLocalizedHref } from '$lib/localized-href';
	import { getLocale, localizeHref } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
	const otherLocale = $derived(locale === 'fr' ? 'en' : 'fr');
	const homeHref = $derived(resolve(normalizeLocalizedHref(localizeHref('/', { locale })) as Pathname));
	const inventoryHref = $derived(resolve(normalizeLocalizedHref(localizeHref('/#inventory', { locale })) as Pathname));
	const insightsHref = $derived(resolve(normalizeLocalizedHref(localizeHref('/#insights', { locale })) as Pathname));
	const privacyHref = $derived(resolve(normalizeLocalizedHref(localizeHref('/#privacy', { locale })) as Pathname));
	const downloadHref = $derived(resolve(normalizeLocalizedHref(localizeHref('/#download', { locale })) as Pathname));
	const localeHref = $derived(resolve(normalizeLocalizedHref(localizeHref(page.url.pathname + page.url.hash, { locale: otherLocale })) as Pathname));
</script>

<header class="site-header">
	<div class="site-container nav-shell">
		<a class="wordmark" href={homeHref} aria-label={locale === 'fr' ? 'Kara — accueil' : 'Kara — home'}>KARA</a>

		<nav aria-label={locale === 'fr' ? 'Navigation principale' : 'Main navigation'}>
			<a href={inventoryHref}>{m.nav_inventory()}</a>
			<a href={insightsHref}>{m.nav_insights()}</a>
			<a href={privacyHref}>{m.nav_privacy()}</a>
		</nav>

		<div class="actions">
			<a
				class="locale-link"
				href={localeHref}
				data-sveltekit-reload
				hreflang={otherLocale}
				lang={otherLocale}
				aria-label={m.language_switch()}
			>
				<Languages size={16} strokeWidth={1.8} aria-hidden="true" />
				<span>{m.language_switch()}</span>
			</a>
			<a class="download-link" href={downloadHref} aria-label={m.nav_download()}>
				<ArrowDownToLine size={16} strokeWidth={2} aria-hidden="true" />
				<span>{m.nav_download()}</span>
			</a>
		</div>
	</div>
</header>

<style>
	.site-header {
		position: fixed;
		z-index: 40;
		top: 0;
		left: 0;
		width: 100%;
		padding-top: env(safe-area-inset-top);
		background: linear-gradient(to bottom, var(--color-void) 0%, oklch(0.075 0 0 / 0.78) 62%, transparent 100%);
	}

	.nav-shell {
		display: grid;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		gap: var(--space-8);
		min-height: 5.25rem;
	}

	.wordmark {
		display: inline-flex;
		min-height: 2.75rem;
		align-items: center;
		padding-inline: 0.25rem;
		font-family: Georgia, 'Times New Roman', serif;
		font-size: 1.08rem;
		letter-spacing: 0.16em;
		line-height: 1;
		transition: color 180ms var(--ease-out-quart);
	}

	.wordmark:hover {
		color: var(--color-gold-bright);
	}

	nav {
		display: flex;
		justify-content: center;
		gap: clamp(1rem, 2.5vw, 2.25rem);
	}

	nav a,
	.locale-link {
		color: var(--color-muted);
		font-size: 0.82rem;
		font-weight: 470;
		transition: color 180ms var(--ease-out-quart);
	}

	nav a {
		display: inline-flex;
		align-items: center;
		min-height: 2.75rem;
	}

	nav a:hover,
	.locale-link:hover {
		color: var(--color-ink);
	}

	.actions,
	.locale-link,
	.download-link {
		display: flex;
		align-items: center;
	}

	.actions {
		gap: var(--space-3);
	}

	.locale-link,
	.download-link {
		justify-content: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		border-radius: 999px;
	}

	.locale-link {
		padding-inline: 0.75rem;
	}

	.download-link {
		padding-inline: 1rem;
		background: var(--color-cobalt);
		color: white;
		font-size: 0.78rem;
		font-weight: 620;
		box-shadow: inset 0 1px 0 oklch(0.86 0.08 258 / 0.36);
		transition: transform 180ms var(--ease-out-quart), background 180ms var(--ease-out-quart);
	}

	.download-link:hover {
		background: oklch(0.61 0.18 258);
		transform: translateY(-1px);
	}

	.download-link:active {
		transform: translateY(0) scale(0.98);
	}

	@media (max-width: 54rem) {
		nav {
			display: none;
		}

		.nav-shell {
			grid-template-columns: auto 1fr;
			gap: var(--space-4);
			min-height: 4.5rem;
		}

		.actions {
			justify-content: end;
		}
	}

	@media (max-width: 32rem) {
		.locale-link span,
		.download-link span {
			display: none;
		}

		.locale-link,
		.download-link {
			width: 2.75rem;
			padding: 0;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.wordmark,
		nav a,
		.locale-link,
		.download-link {
			transition: none;
		}
	}
</style>
