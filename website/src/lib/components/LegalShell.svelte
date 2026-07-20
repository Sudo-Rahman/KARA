<script lang="ts">
	import type { Pathname } from '$app/types';
	import { resolve } from '$app/paths';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { normalizeLocalizedHref } from '$lib/localized-href';
	import type { EditorialDocument, EditorialLocale } from '$lib/content/editorial';

	let {
		content,
		locale,
		currentPath,
		supportEmail,
		legalName
	}: {
		content: EditorialDocument;
		locale: EditorialLocale;
		currentPath: '/privacy' | '/support';
		supportEmail: string;
		legalName: string;
	} = $props();

	const alternativeLocale = $derived(
		({ fr: 'en', en: 'fr' } satisfies Record<EditorialLocale, EditorialLocale>)[locale]
	);
	const homeHref = $derived(normalizeLocalizedHref(localizeHref('/', { locale })) as Pathname);
	const privacyHref = $derived(localizeHref('/privacy', { locale }) as Pathname);
	const supportHref = $derived(localizeHref('/support', { locale }) as Pathname);
	const alternativeHref = $derived(
		localizeHref(currentPath, { locale: alternativeLocale }) as Pathname
	);
	const normalizedSupportEmail = $derived(supportEmail.trim());
</script>

<div class="legal-shell">
	<div class="ambient ambient-one" aria-hidden="true"></div>
	<div class="ambient ambient-two" aria-hidden="true"></div>

	<header class="site-header">
		<div class="header-inner">
			<a class="brand" href={resolve(homeHref)} aria-label={content.backHomeLabel}>
				<span class="brand-mark" aria-hidden="true">K</span>
				<span class="wordmark">KARA</span>
			</a>

			<nav
				class="header-navigation"
				aria-label={locale === 'fr' ? 'Navigation des pages' : 'Page navigation'}
			>
				<div class="section-links">
					<a href={resolve(privacyHref)} aria-current={currentPath === '/privacy' ? 'page' : undefined}>
						{content.privacyLabel}
					</a>
					<a href={resolve(supportHref)} aria-current={currentPath === '/support' ? 'page' : undefined}>
						{content.supportLabel}
					</a>
				</div>
				<a
					class="language-link"
					href={resolve(alternativeHref)}
					data-sveltekit-reload
					hreflang={alternativeLocale}
					lang={alternativeLocale}
					aria-label={content.languageLabel}
				>
					{content.alternativeLanguage}
				</a>
			</nav>
		</div>
	</header>

	<main id="main-content" tabindex="-1">
		<header class="page-hero">
			<div class="hero-copy">
				<h1>{content.title}</h1>
				<p class="introduction">{content.intro}</p>
				<p class="updated">
					{content.updatedLabel}
					<time datetime={content.updatedDateIso}>{content.updatedDate}</time>
				</p>
			</div>

			<ul class="highlights" aria-label={content.eyebrow}>
				{#each content.highlights as highlight (highlight)}
					<li>
						<span class="highlight-mark" aria-hidden="true"></span>
						<span>{highlight}</span>
					</li>
				{/each}
			</ul>
		</header>

		<div class="reading-layout">
			<aside class="contents">
				<nav aria-labelledby="contents-title">
					<h2 id="contents-title">{content.contentsLabel}</h2>
					<ol>
						{#each content.sections as section (section.id)}
							<li>
								<a href={`#${section.id}`}>{section.title}</a>
							</li>
						{/each}
					</ol>
				</nav>
			</aside>

			<article class="document">
				{#each content.sections as section (section.id)}
					<section
						class:contact-section={section.kind === 'contact'}
						id={section.id}
						aria-labelledby={`${section.id}-title`}
					>
						<h2 id={`${section.id}-title`}>{section.title}</h2>

						{#if section.kind === 'text'}
							{#if section.intro}<p class="section-intro">{section.intro}</p>{/if}

							{#each section.paragraphs ?? [] as paragraph (paragraph)}
								<p>{paragraph}</p>
							{/each}

							{#if section.points?.length}
								<dl class="points">
									{#each section.points as point (point.title)}
										<div>
											<dt>{point.title}</dt>
											<dd>{point.body}</dd>
										</div>
									{/each}
								</dl>
							{/if}

							{#if section.bullets?.length}
								<ul class="bullets">
									{#each section.bullets as bullet (bullet)}
										<li>{bullet}</li>
									{/each}
								</ul>
							{/if}

							{#if section.note}
								<aside class="note">{section.note}</aside>
							{/if}
						{:else if section.kind === 'faq'}
							{#if section.intro}<p class="section-intro">{section.intro}</p>{/if}
							<div class="faq-list">
								{#each section.items as item (item.question)}
									<details>
										<summary>
											<span>{item.question}</span>
											<span class="faq-icon" aria-hidden="true"></span>
										</summary>
										<div class="faq-answer">
											{#each item.answer as paragraph (paragraph)}
												<p>{paragraph}</p>
											{/each}
										</div>
									</details>
								{/each}
							</div>
						{:else}
							{#each section.paragraphs as paragraph (paragraph)}
								<p>{paragraph}</p>
							{/each}

							{#if normalizedSupportEmail}
								<a
									class="email-link"
									href={`mailto:${normalizedSupportEmail}?subject=${encodeURIComponent(section.emailSubject)}`}
								>
									<span>{section.emailLabel}</span>
									<span class="email-address">{normalizedSupportEmail}</span>
									<svg viewBox="0 0 24 24" aria-hidden="true">
										<path d="M5 19 19 5M8 5h11v11" />
									</svg>
								</a>
							{:else}
								<p class="email-unavailable">{section.emailUnavailable}</p>
							{/if}
						{/if}
					</section>
				{/each}
			</article>
		</div>
	</main>

	<footer class="site-footer">
		<div class="footer-inner">
			<div>
				<a class="footer-wordmark" href={resolve(homeHref)}>KARA</a>
				<p>{content.footerTagline}</p>
			</div>
			<div class="footer-meta">
				<p>{content.legalOperatorLabel} {legalName}</p>
				<nav aria-label={locale === 'fr' ? 'Liens de pied de page' : 'Footer links'}>
					<a href={resolve(privacyHref)}>{content.privacyLabel}</a>
					<a href={resolve(supportHref)}>{content.supportLabel}</a>
				</nav>
			</div>
		</div>
	</footer>
</div>

<style>
	.legal-shell,
	.legal-shell *,
	.legal-shell *::before,
	.legal-shell *::after {
		box-sizing: border-box;
	}

	.legal-shell {
		position: relative;
		isolation: isolate;
		min-height: 100svh;
		overflow: clip;
		background:
			linear-gradient(180deg, transparent 0 640px, oklch(0.09 0.008 258 / 0.72) 900px),
			var(--color-void, oklch(0.075 0 0));
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-family: var(--font-sans, 'Geologica', system-ui, sans-serif);
		font-weight: 400;
	}

	.ambient {
		position: absolute;
		z-index: -1;
		border-radius: 999px;
		pointer-events: none;
		filter: blur(2px);
	}

	.ambient-one {
		top: -340px;
		right: -280px;
		width: min(820px, 80vw);
		aspect-ratio: 1;
		background: radial-gradient(circle, oklch(0.46 0.19 258 / 0.25), transparent 68%);
	}

	.ambient-two {
		top: 540px;
		left: -360px;
		width: 680px;
		aspect-ratio: 1;
		background: radial-gradient(circle, oklch(0.42 0.15 258 / 0.13), transparent 70%);
	}

	.site-header {
		position: sticky;
		top: 0;
		z-index: 20;
		padding-top: env(safe-area-inset-top, 0px);
		border-bottom: 1px solid oklch(0.29 0.018 258 / 0.55);
		background: oklch(0.075 0 0 / 0.83);
		backdrop-filter: blur(18px) saturate(130%);
	}

	.header-inner,
	.page-hero,
	.reading-layout,
	.footer-inner {
		width: min(100%, calc(var(--content-max, 80rem) + var(--page-gutter, clamp(1rem, 3.5vw, 3.5rem)) * 2));
		margin-inline: auto;
		padding-left: max(var(--page-gutter, clamp(1rem, 3.5vw, 3.5rem)), env(safe-area-inset-left, 0px));
		padding-right: max(var(--page-gutter, clamp(1rem, 3.5vw, 3.5rem)), env(safe-area-inset-right, 0px));
	}

	.header-inner {
		display: flex;
		min-height: 72px;
		align-items: center;
		justify-content: space-between;
		gap: 24px;
	}

	.brand {
		display: inline-flex;
		min-height: 44px;
		align-items: center;
		gap: 10px;
		color: inherit;
		text-decoration: none;
	}

	.brand-mark {
		display: grid;
		width: 30px;
		height: 30px;
		place-items: center;
		border: 1px solid oklch(0.8 0.13 88 / 0.62);
		border-radius: 3px;
		color: var(--color-gold, oklch(0.8 0.13 88));
		font-family: Georgia, serif;
		font-size: 14px;
	}

	.wordmark,
	.footer-wordmark {
		font-family: Georgia, serif;
		font-size: 15px;
		letter-spacing: 0.19em;
	}

	.header-navigation,
	.section-links {
		display: flex;
		align-items: center;
	}

	.header-navigation {
		gap: clamp(12px, 3vw, 40px);
	}

	.section-links {
		gap: clamp(16px, 2.5vw, 32px);
	}

	.header-navigation a {
		display: inline-flex;
		min-height: 44px;
		align-items: center;
		color: var(--color-muted, oklch(0.69 0.014 258));
		font-size: var(--text-label, 0.82rem);
		text-decoration: none;
		transition: color 180ms ease-out;
	}

	.header-navigation a:hover,
	.header-navigation a[aria-current='page'] {
		color: var(--color-ink, oklch(0.965 0.006 95));
	}

	.header-navigation a[aria-current='page'] {
		text-decoration: underline;
		text-decoration-color: var(--color-cobalt-bright, oklch(0.72 0.15 258));
		text-decoration-thickness: 2px;
		text-underline-offset: 7px;
	}

	.language-link {
		border: 1px solid var(--color-line, oklch(0.29 0.018 258));
		border-radius: 999px;
		padding-inline: 16px;
	}

	.page-hero {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(250px, 0.42fr);
		gap: clamp(48px, 8vw, 128px);
		align-items: end;
		padding-block: clamp(88px, 13vw, 176px) clamp(72px, 10vw, 128px);
	}

	.hero-copy {
		max-width: 850px;
	}

	h1 {
		max-width: 12ch;
		margin: 0;
		font-size: var(--text-display, clamp(3rem, 7vw, 6rem));
		font-weight: 440;
		letter-spacing: -0.04em;
		line-height: 0.98;
		text-wrap: balance;
	}

	.introduction {
		max-width: 68ch;
		margin: clamp(28px, 4vw, 48px) 0 0;
		color: oklch(0.8 0.012 258);
		font-size: clamp(1.05rem, 1.4vw, 1.24rem);
		line-height: 1.68;
	}

	.updated {
		margin: 24px 0 0;
		color: var(--color-muted, oklch(0.69 0.014 258));
		font-size: var(--text-label, 0.82rem);
	}

	.updated time::before {
		content: ' · ';
	}

	.highlights {
		margin: 0;
		padding: 0;
		border-top: 1px solid var(--color-line, oklch(0.29 0.018 258));
		list-style: none;
	}

	.highlights li {
		display: grid;
		grid-template-columns: 32px 1fr;
		gap: 12px;
		align-items: center;
		min-height: 72px;
		border-bottom: 1px solid var(--color-line, oklch(0.29 0.018 258));
		font-size: var(--text-small, 0.9rem);
		line-height: 1.4;
	}

	.highlight-mark {
		width: 7px;
		height: 7px;
		border-radius: 50%;
		background: var(--color-cobalt-bright, oklch(0.72 0.15 258));
		box-shadow: 0 0 16px oklch(0.72 0.15 258 / 0.6);
	}

	.reading-layout {
		display: grid;
		grid-template-columns: 230px minmax(0, 760px);
		gap: clamp(56px, 9vw, 136px);
		justify-content: center;
		align-items: start;
		padding-bottom: clamp(96px, 12vw, 160px);
	}

	.contents {
		position: sticky;
		top: 112px;
	}

	.contents h2 {
		margin: 0 0 20px;
		color: var(--color-muted, oklch(0.69 0.014 258));
		font-size: var(--text-micro, 0.75rem);
		font-weight: 550;
		letter-spacing: 0.12em;
		text-transform: uppercase;
	}

	.contents ol {
		margin: 0;
		padding: 0;
		border-top: 1px solid var(--color-line, oklch(0.29 0.018 258));
		list-style: none;
	}

	.contents li {
		border-bottom: 1px solid oklch(0.29 0.018 258 / 0.58);
	}

	.contents a {
		display: flex;
		align-items: center;
		min-height: 48px;
		color: var(--color-muted, oklch(0.69 0.014 258));
		font-size: var(--text-label, 0.82rem);
		line-height: 1.35;
		text-decoration: none;
		transition: color 180ms ease-out;
	}

	.contents a:hover {
		color: var(--color-ink, oklch(0.965 0.006 95));
	}

	.document section {
		scroll-margin-top: 112px;
		padding: 0 0 clamp(64px, 8vw, 104px);
		border-top: 1px solid var(--color-line, oklch(0.29 0.018 258));
	}

	.document section + section {
		padding-top: clamp(64px, 8vw, 104px);
	}

	.document h2 {
		max-width: 15ch;
		margin: 0 0 32px;
		font-size: var(--text-editorial-section, clamp(2rem, 4vw, 3.4rem));
		font-weight: 450;
		letter-spacing: -0.04em;
		line-height: 1.05;
		text-wrap: balance;
	}

	.document p,
	.document li,
	.document dd {
		color: oklch(0.79 0.012 258);
		font-size: 1rem;
		line-height: 1.72;
	}

	.document section > p,
	.section-intro {
		max-width: 68ch;
		margin: 0 0 18px;
	}

	.document .section-intro {
		margin-bottom: 28px;
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-size: 1.08rem;
	}

	.points {
		margin: 36px 0 0;
		border-top: 1px solid oklch(0.29 0.018 258 / 0.72);
	}

	.points div {
		display: grid;
		grid-template-columns: minmax(130px, 0.34fr) 1fr;
		gap: 24px;
		padding: 24px 0;
		border-bottom: 1px solid oklch(0.29 0.018 258 / 0.72);
	}

	.points dt {
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-size: 0.9rem;
		font-weight: 550;
		line-height: 1.5;
	}

	.points dd {
		margin: 0;
	}

	.bullets {
		display: grid;
		gap: 16px;
		max-width: 68ch;
		margin: 30px 0;
		padding: 0;
		list-style: none;
	}

	.bullets li {
		position: relative;
		padding-left: 26px;
	}

	.bullets li::before {
		position: absolute;
		top: 0.72em;
		left: 0;
		width: 8px;
		height: 1px;
		background: var(--color-cobalt-bright, oklch(0.72 0.15 258));
		content: '';
	}

	.note {
		max-width: 68ch;
		margin-top: 32px;
		border: 1px solid oklch(0.56 0.18 258 / 0.62);
		background: oklch(0.17 0.016 258 / 0.5);
		padding: 20px 22px;
		color: oklch(0.85 0.012 258);
		font-size: 0.9rem;
		line-height: 1.65;
	}

	.faq-list {
		margin-top: 32px;
		border-top: 1px solid var(--color-line, oklch(0.29 0.018 258));
	}

	.faq-list details {
		border-bottom: 1px solid var(--color-line, oklch(0.29 0.018 258));
	}

	.faq-list summary {
		display: grid;
		grid-template-columns: 1fr 24px;
		gap: 24px;
		align-items: center;
		min-height: 76px;
		padding: 18px 2px;
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-size: 1rem;
		font-weight: 500;
		line-height: 1.45;
		cursor: pointer;
		list-style: none;
	}

	.faq-list summary::-webkit-details-marker {
		display: none;
	}

	.faq-icon {
		position: relative;
		display: block;
		width: 20px;
		height: 20px;
	}

	.faq-icon::before,
	.faq-icon::after {
		position: absolute;
		top: 9px;
		left: 3px;
		width: 14px;
		height: 1px;
		background: var(--color-cobalt-bright, oklch(0.72 0.15 258));
		content: '';
		transition: transform 180ms ease-out;
	}

	.faq-icon::after {
		transform: rotate(90deg);
	}

	details[open] .faq-icon::after {
		transform: rotate(0deg);
	}

	.faq-answer {
		max-width: 64ch;
		padding: 0 48px 24px 2px;
	}

	.faq-answer p {
		margin: 0 0 12px;
	}

	.document section.contact-section {
		position: relative;
		margin-top: 8px;
		border: 1px solid oklch(0.56 0.18 258 / 0.5);
		background:
			radial-gradient(circle at 100% 0, oklch(0.56 0.18 258 / 0.22), transparent 52%),
			var(--color-surface, oklch(0.125 0.012 258));
		padding: clamp(28px, 5vw, 56px);
	}

	.email-link {
		display: grid;
		grid-template-columns: auto 1fr 24px;
		gap: 16px;
		align-items: center;
		min-height: 58px;
		margin-top: 32px;
		border-radius: 3px;
		background: var(--color-cobalt, oklch(0.56 0.18 258));
		padding: 8px 16px 8px 20px;
		color: white;
		font-size: 0.92rem;
		font-weight: 600;
		text-decoration: none;
		transition: background 180ms ease-out;
	}

	.email-link:hover {
		background: oklch(0.61 0.18 258);
	}

	.email-address {
		overflow: hidden;
		color: white;
		font-size: 0.8rem;
		font-weight: 400;
		text-align: right;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.email-link svg {
		width: 20px;
		fill: none;
		stroke: currentColor;
		stroke-linecap: round;
		stroke-linejoin: round;
		stroke-width: 1.6;
	}

	.document .email-unavailable {
		margin-top: 28px;
		border: 1px solid var(--color-line, oklch(0.29 0.018 258));
		padding: 18px;
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-size: 0.9rem;
	}

	.site-footer {
		border-top: 1px solid var(--color-line, oklch(0.29 0.018 258));
		background: oklch(0.06 0 0);
	}

	.footer-inner {
		display: flex;
		justify-content: space-between;
		gap: 48px;
		padding-top: 48px;
		padding-bottom: max(48px, env(safe-area-inset-bottom, 0px));
	}

	.footer-wordmark {
		display: inline-block;
		min-height: 44px;
		color: var(--color-ink, oklch(0.965 0.006 95));
		line-height: 44px;
		text-decoration: none;
	}

	.site-footer p {
		margin: 4px 0 0;
		color: var(--color-muted, oklch(0.69 0.014 258));
		font-size: var(--text-micro, 0.75rem);
		line-height: 1.6;
	}

	.footer-meta {
		text-align: right;
	}

	.footer-meta nav {
		display: flex;
		justify-content: flex-end;
		gap: 22px;
		margin-top: 12px;
	}

	.footer-meta a {
		display: inline-flex;
		min-height: 44px;
		align-items: center;
		color: var(--color-ink, oklch(0.965 0.006 95));
		font-size: var(--text-label, 0.82rem);
		text-decoration: none;
	}

	:where(a, summary):focus-visible {
		outline: 3px solid var(--color-cobalt-bright, oklch(0.72 0.15 258));
		outline-offset: 4px;
	}

	@media (max-width: 56.25rem) {
		.page-hero {
			grid-template-columns: 1fr;
		}

		.highlights {
			display: grid;
			grid-template-columns: repeat(3, 1fr);
		}

		.highlights li {
			grid-template-columns: 12px 1fr;
			align-content: center;
			padding: 12px 18px;
			border-right: 1px solid var(--color-line, oklch(0.29 0.018 258));
		}

		.highlights li:last-child {
			border-right: 0;
		}

		.reading-layout {
			grid-template-columns: 1fr;
			gap: 64px;
		}

		.contents {
			position: static;
		}

		.contents ol {
			display: grid;
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}

		.contents li:nth-child(odd) {
			border-right: 1px solid oklch(0.29 0.018 258 / 0.58);
		}

		.contents a {
			padding: 6px 12px;
		}
	}

	@media (max-width: 40rem) {
		.header-inner {
			min-height: 64px;
		}

		.brand-mark {
			display: none;
		}

		.section-links a[aria-current='page'] {
			display: none;
		}

		.language-link {
			padding-inline: 14px;
		}

		.page-hero {
			gap: 48px;
			padding-block: 72px 80px;
		}

		.highlights {
			display: block;
		}

		.highlights li {
			grid-template-columns: 20px 1fr;
			min-height: 62px;
			padding: 0;
			border-right: 0;
		}

		.contents ol {
			display: block;
		}

		.contents li:nth-child(odd) {
			border-right: 0;
		}

		.contents a {
			padding-inline: 0;
		}

		.document h2 {
			margin-bottom: 26px;
		}

		.points div {
			grid-template-columns: 1fr;
			gap: 8px;
		}

		.faq-list summary {
			min-height: 68px;
			gap: 16px;
		}

		.faq-answer {
			padding-right: 0;
		}

		.contact-section {
			margin-inline: -8px;
		}

		.email-link {
			grid-template-columns: 1fr 20px;
		}

		.email-address {
			display: none;
		}

		.footer-inner {
			flex-direction: column;
			gap: 24px;
		}

		.footer-meta,
		.footer-meta nav {
			justify-content: flex-start;
			text-align: left;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		*,
		*::before,
		*::after {
			scroll-behavior: auto !important;
			transition-duration: 0.01ms !important;
		}
	}

	@media print {
		.site-header,
		.ambient,
		.contents,
		.site-footer,
		.email-link {
			display: none;
		}

		.legal-shell {
			background: white;
			color: black;
		}

		.page-hero,
		.reading-layout {
			width: 100%;
			padding-block: 32px;
		}

		.reading-layout {
			display: block;
		}

		.document p,
		.document li,
		.document dd,
		.introduction,
		.updated {
			color: #222;
		}

		.document section,
		.contact-section {
			break-inside: avoid;
			border-color: #bbb !important;
			background: white;
		}
	}
</style>
