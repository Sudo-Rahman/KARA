<script lang="ts">
	import { MediaQuery } from 'svelte/reactivity';
	import { publicConfig } from '$lib/config';
	import { getLocale } from '$lib/paraglide/runtime';
	import StoreBadge, { type StorePlatform } from './StoreBadge.svelte';

	let {
		appStoreUrl = publicConfig.appStoreUrl,
		googlePlayUrl = publicConfig.googlePlayUrl,
		showQr = true
	}: {
		appStoreUrl?: string | null;
		googlePlayUrl?: string | null;
		showQr?: boolean;
	} = $props();

	const labels = {
		fr: {
			group: 'Télécharger Kara',
			apple: 'Télécharger Kara dans l’App Store',
			google: 'Télécharger Kara sur Google Play',
			scan: 'Scanner pour télécharger',
			unavailable: 'Bientôt disponible'
		},
		en: {
			group: 'Download Kara',
			apple: 'Download Kara on the App Store',
			google: 'Download Kara on Google Play',
			scan: 'Scan to download',
			unavailable: 'Coming soon'
		}
	} as const;

	const copy = $derived(labels[getLocale()]);
	const desktop = new MediaQuery('(min-width: 64rem)', false);
	const qrOptions = {
		type: 'svg',
		errorCorrectionLevel: 'H',
		margin: 1,
		width: 128,
		color: { dark: '#090909ff', light: '#f7f3eaff' }
	} as const;

	async function createQrDataUrl(value: string): Promise<string> {
		const { default: QRCode } = await import('qrcode');
		const svg = await QRCode.toString(value, qrOptions);
		return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
	}

	const appStoreQr = $derived(
		showQr && desktop.current && appStoreUrl
			? createQrDataUrl(appStoreUrl)
			: Promise.resolve(null)
	);
	const googlePlayQr = $derived(
		showQr && desktop.current && googlePlayUrl
			? createQrDataUrl(googlePlayUrl)
			: Promise.resolve(null)
	);

	const stores = $derived([
		{
			platform: 'apple' as const,
			url: appStoreUrl,
			label: copy.apple,
			event: 'download_app_store',
			qr: appStoreQr
		},
		{
			platform: 'google' as const,
			url: googlePlayUrl,
			label: copy.google,
			event: 'download_google_play',
			qr: googlePlayQr
		}
	] satisfies Array<{
		platform: StorePlatform;
		url: string | null;
		label: string;
		event: 'download_app_store' | 'download_google_play';
		qr: Promise<string | null>;
	}>);
</script>

<div class="store-links" role="group" aria-label={copy.group}>
	{#each stores as store (store.platform)}
		<div class="store-option">
			{#if store.url}
				<a
					class="store-action"
					href={store.url}
					target="_blank"
					rel="noopener noreferrer"
					aria-label={store.label}
					data-umami-event={store.event}
				>
					<StoreBadge platform={store.platform} />
					{#if showQr}
						<span class="store-qr-frame" aria-hidden="true">
							{#await store.qr}
								<span class="store-qr-skeleton"></span>
							{:then qr}
								{#if qr}
									<span class="store-qr"><img src={qr} alt="" width="104" height="104" /></span>
								{/if}
							{:catch}
								<span class="store-qr-error"></span>
							{/await}
						</span>
						<span class="store-qr-caption">{copy.scan}</span>
					{/if}
				</a>
			{:else}
				<span
					class="store-action store-action--disabled"
					role="link"
					aria-disabled="true"
					aria-label={`${store.label} — ${copy.unavailable}`}
				>
					<StoreBadge platform={store.platform} disabled />
					<span class="store-unavailable">{copy.unavailable}</span>
				</span>
			{/if}
		</div>
	{/each}
</div>

<style>
	.store-links {
		display: flex;
		width: 100%;
		flex-wrap: wrap;
		align-items: flex-start;
		gap: clamp(1rem, 3vw, 2rem);
	}

	.store-option {
		display: grid;
		min-width: 0;
		flex: 0 1 12.5rem;
		place-items: start center;
	}

	.store-action {
		display: grid;
		width: 100%;
		justify-items: center;
		color: inherit;
		text-decoration: none;
	}

	.store-action:not(.store-action--disabled):focus-visible {
		border-radius: 0.72rem;
		outline: 3px solid var(--color-cobalt-bright, #6e9cff);
		outline-offset: 5px;
	}

	.store-action--disabled {
		cursor: not-allowed;
	}

	.store-unavailable,
	.store-qr-caption {
		margin-top: 0.55rem;
		font-family: inherit;
		font-size: 0.72rem;
		font-weight: 430;
		letter-spacing: 0.02em;
	}

	.store-unavailable {
		color: var(--color-muted, #9b9daa);
	}

	.store-qr-frame,
	.store-qr-caption {
		display: none;
	}

	.store-qr-frame {
		box-sizing: border-box;
		width: 7rem;
		height: 7rem;
		margin-top: 0.9rem;
		padding: 0.35rem;
		border: 1px solid color-mix(in oklab, var(--color-line, #41434b) 72%, transparent);
		border-radius: 0.7rem;
		background: #f7f3ea;
	}

	.store-qr,
	.store-qr-skeleton,
	.store-qr-error {
		display: block;
		width: 100%;
		height: 100%;
	}

	.store-qr-skeleton {
		border-radius: 0.35rem;
		background:
			linear-gradient(90deg, transparent 35%, rgb(255 255 255 / 50%), transparent 65%),
			#e8e3d9;
		background-size: 220% 100%;
		animation: qr-loading 1.2s linear infinite;
	}

	.store-qr-error {
		border-radius: 0.35rem;
		background:
			linear-gradient(45deg, transparent 48%, #b2aca1 49%, #b2aca1 51%, transparent 52%),
			linear-gradient(-45deg, transparent 48%, #b2aca1 49%, #b2aca1 51%, transparent 52%),
			#e8e3d9;
	}

	.store-qr :global(img) {
		display: block;
		width: 100%;
		height: 100%;
	}

	.store-qr-caption {
		color: var(--color-muted, #9b9daa);
	}

	@keyframes qr-loading {
		to {
			background-position: -220% 0;
		}
	}

	@media (min-width: 64rem) {
		.store-qr-frame,
		.store-qr-caption {
			display: block;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.store-qr-skeleton {
			animation: none;
		}
	}
</style>
