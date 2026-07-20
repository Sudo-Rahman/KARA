<script lang="ts">
	import type { Pathname } from '$app/types';
	import { resolve } from '$app/paths';
	import { m } from '$lib/paraglide/messages';
	import { getLocale, localizeHref } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
	const privacyHref = $derived(resolve(localizeHref('/privacy', { locale }) as Pathname));
	const supportHref = $derived(resolve(localizeHref('/support', { locale }) as Pathname));
</script>

<footer>
	<div class="site-container footer-grid">
		<div>
			<div class="wordmark">KARA</div>
			<p>{m.footer_tagline()}</p>
		</div>
		<nav aria-label={locale === 'fr' ? 'Liens de pied de page' : 'Footer links'}>
			<a href={privacyHref}>{m.footer_privacy()}</a>
			<a href={supportHref}>{m.footer_support()}</a>
		</nav>
		<p class="copyright">{m.footer_copyright({ year: new Date().getFullYear().toString() })}</p>
		<p class="store-legal">{m.footer_store_legal()}</p>
	</div>
</footer>

<style>
	footer {
		position: relative;
		z-index: 4;
		padding: var(--space-16) 0 max(var(--space-8), env(safe-area-inset-bottom));
		border-top: 1px solid var(--color-line);
		background: var(--color-void);
	}

	.footer-grid {
		display: grid;
		grid-template-columns: 1.2fr 1fr auto;
		align-items: end;
		gap: var(--space-8);
	}

	.wordmark {
		margin-bottom: var(--space-3);
		font-family: Georgia, 'Times New Roman', serif;
		font-size: 1rem;
		letter-spacing: 0.16em;
	}

	p,
	a {
		color: var(--color-muted);
		font-size: 0.8rem;
	}

	nav {
		display: flex;
		justify-content: center;
		gap: var(--space-6);
	}

	a {
		min-height: 2.75rem;
		display: inline-flex;
		align-items: center;
		transition: color 180ms var(--ease-out-quart);
	}

	a:hover {
		color: var(--color-ink);
	}

	.copyright {
		text-align: right;
	}

	.store-legal {
		grid-column: 1 / -1;
		max-width: 90ch;
		color: var(--color-muted);
		font-size: var(--text-micro);
		line-height: 1.55;
	}

	@media (max-width: 48rem) {
		.footer-grid {
			grid-template-columns: 1fr;
			align-items: start;
		}

		nav {
			justify-content: start;
			flex-wrap: wrap;
		}

		.copyright {
			text-align: left;
		}
	}
</style>
