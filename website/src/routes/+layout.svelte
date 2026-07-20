<script lang="ts">
	import '@fontsource-variable/geologica';
	import { getLocale } from '$lib/paraglide/runtime';
	import './layout.css';

	let { children } = $props();
	const skipLabel = $derived(getLocale() === 'fr' ? 'Aller au contenu' : 'Skip to content');
</script>

<svelte:head>
	<link rel="icon" href="/brand/kara-app-icon.png" />
	<link rel="apple-touch-icon" href="/brand/kara-app-icon.png" />
	<meta name="theme-color" content="#050507" />
</svelte:head>

<a class="skip-link" href="#main-content">{skipLabel}</a>
{@render children()}
