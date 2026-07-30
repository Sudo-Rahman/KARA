<script lang="ts">
	let {
		src,
		alt,
		class: className = '',
		priority = false
	}: {
		src: string;
		alt: string;
		class?: string;
		priority?: boolean;
	} = $props();
</script>

<figure class={`device ${className}`} aria-label={alt}>
	<div class="device__rail" aria-hidden="true"></div>
	<div class="device__shell">
		<img
			{src}
			{alt}
			width="368"
			height="800"
			loading={priority ? 'eager' : 'lazy'}
			fetchpriority={priority ? 'high' : 'auto'}
			decoding="async"
		/>
	</div>
</figure>

<style>
	.device {
		position: relative;
		width: min(100%, 23rem);
		margin: 0;
		isolation: isolate;
		filter: drop-shadow(0 2rem 3rem oklch(0% 0 0 / 0.42));
		transform: translateZ(0);
	}

	.device__rail {
		position: absolute;
		inset: 3.8% -1.15% 4%;
		border-radius: 13.1% / 6%;
		background: linear-gradient(
			100deg,
			oklch(0.19 0.014 258),
			oklch(0.64 0.03 88) 8%,
			oklch(0.23 0.018 258) 21%,
			oklch(0.13 0.01 258) 50%,
			oklch(0.48 0.025 258) 82%,
			oklch(0.16 0.012 258)
		);
		box-shadow:
			inset 0 0 0 1px oklch(0.82 0.025 88 / 0.22),
			inset 0.12rem 0 0.22rem oklch(1 0 0 / 0.08),
			inset -0.12rem 0 0.22rem oklch(0 0 0 / 0.58);
	}

	.device__rail::before,
	.device__rail::after {
		position: absolute;
		z-index: -1;
		width: 1.45%;
		border-radius: 999px;
		background: linear-gradient(oklch(0.5 0.025 258), oklch(0.12 0.01 258));
		box-shadow: inset 0 0 0 1px oklch(0.82 0.025 88 / 0.2);
		content: '';
	}

	.device__rail::before {
		top: 24%;
		left: -0.8%;
		height: 15%;
	}

	.device__rail::after {
		top: 29%;
		right: -0.8%;
		height: 12%;
	}

	.device__shell {
		position: relative;
		overflow: hidden;
		padding: 1.65%;
		border: 1px solid transparent;
		border-radius: 12.45% / 5.72%;
		background:
			linear-gradient(oklch(0.12 0.008 258), oklch(0.055 0.004 258)) padding-box,
			linear-gradient(
					145deg,
					oklch(0.75 0.035 88),
					oklch(0.22 0.018 258) 28%,
					oklch(0.5 0.035 258) 72%,
					oklch(0.18 0.015 258)
				)
				border-box;
	}

	.device__shell::after {
		position: absolute;
		inset: 1.7%;
		z-index: 2;
		border-radius: 11.2% / 5.15%;
		box-shadow:
			inset 0 0 0 1px oklch(1 0 0 / 0.12),
			inset 0 0.45rem 0.9rem oklch(1 0 0 / 0.035);
		pointer-events: none;
		content: '';
	}

	img {
		display: block;
		width: 100%;
		height: auto;
		border-radius: 11.2% / 5.15%;
		background: oklch(0.04 0 0);
	}

	@media (prefers-reduced-motion: reduce) {
		.device {
			filter: drop-shadow(0 1rem 1.5rem oklch(0% 0 0 / 0.34));
		}
	}
</style>
