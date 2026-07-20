<script lang="ts">
	import { getLocale } from '$lib/paraglide/runtime';

	export type StorePlatform = 'apple' | 'google';

	let { platform, disabled = false }: { platform: StorePlatform; disabled?: boolean } = $props();

	const locale = $derived(getLocale());
	const source = $derived(
		platform === 'apple'
			? locale === 'fr'
				? '/store/app-store-fr.svg'
				: '/store/app-store.svg'
			: locale === 'fr'
				? '/store/google-play-fr.png'
				: '/store/google-play-en.png'
	);
</script>

<span class:disabled class="store-badge" data-platform={platform}>
	<img
		src={source}
		alt=""
		width={platform === 'apple' ? 135 : 646}
		height={platform === 'apple' ? 40 : 250}
		draggable="false"
	/>
</span>

<style>
	.store-badge {
		display: grid;
		width: 100%;
		min-width: 11.25rem;
		max-width: 12.5rem;
		height: 5.25rem;
		place-items: center;
	}

	.store-badge img {
		display: block;
		width: 100%;
		height: auto;
		user-select: none;
	}

	.store-badge[data-platform='apple'] img {
		width: 94%;
	}

	.store-badge.disabled {
		opacity: 0.42;
		filter: grayscale(0.2);
	}
</style>
