<script lang="ts">
	import LegalShell from '$lib/components/LegalShell.svelte';
	import { publicConfig } from '$lib/config';
	import { supportContent } from '$lib/content/support';
	import { getLocale, localizeHref } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
	const content = $derived(supportContent[locale]);
	const siteUrl = publicConfig.siteUrl ?? 'http://localhost';
	const canonicalHref = $derived(new URL(localizeHref('/support', { locale }), siteUrl).href);
	const frenchHref = $derived(new URL(
		localizeHref('/support', { locale: 'fr' }),
		siteUrl
	).href);
	const englishHref = $derived(new URL(
		localizeHref('/support', { locale: 'en' }),
		siteUrl
	).href);
	const socialImage = new URL('/brand/kara-og.png', siteUrl).href;
</script>

<svelte:head>
	<title>{content.metaTitle}</title>
	<meta name="description" content={content.metaDescription} />
	<meta name="robots" content="index,follow" />
	<link rel="canonical" href={canonicalHref} />
	<link rel="alternate" hreflang="fr" href={frenchHref} />
	<link rel="alternate" hreflang="en" href={englishHref} />
	<link rel="alternate" hreflang="x-default" href={frenchHref} />
	<meta property="og:type" content="website" />
	<meta property="og:title" content={content.metaTitle} />
	<meta property="og:description" content={content.metaDescription} />
	<meta property="og:url" content={canonicalHref} />
	<meta property="og:locale" content={locale === 'fr' ? 'fr_FR' : 'en_US'} />
	<meta property="og:image" content={socialImage} />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content={content.metaTitle} />
	<meta name="twitter:card" content="summary_large_image" />
</svelte:head>

<LegalShell
	{content}
	{locale}
	currentPath="/support"
	supportEmail={publicConfig.supportEmail ?? ''}
	legalName={publicConfig.legalName ?? 'Kara'}
/>
