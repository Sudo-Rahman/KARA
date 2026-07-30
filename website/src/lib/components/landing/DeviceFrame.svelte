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
		<div class="device__island" aria-hidden="true"></div>
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
		filter: drop-shadow(0 2rem 3rem oklch(0% 0 0 / 0.42));
		transform: translateZ(0);
	}

	.device__rail {
		position: absolute;
		inset: 8% -0.25rem 9%;
		border-radius: 2.7rem;
		background: linear-gradient(
			100deg,
			oklch(0.27 0.018 258),
			oklch(0.5 0.028 88) 16%,
			oklch(0.17 0.014 258) 44%,
			oklch(0.42 0.025 258) 78%,
			oklch(0.2 0.014 258)
		);
	}

	.device__shell {
		position: relative;
		overflow: hidden;
		padding: 0.42rem;
		border-radius: 3.1rem;
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
		border: 1px solid transparent;
	}

	.device__shell::after {
		position: absolute;
		inset: 0.48rem;
		z-index: 2;
		border-radius: 2.66rem;
		box-shadow:
			inset 0 0 0 1px oklch(1 0 0 / 0.12),
			inset 0 0.7rem 1.4rem oklch(1 0 0 / 0.035);
		pointer-events: none;
		content: '';
	}

	.device__island {
		position: absolute;
		top: 1rem;
		left: 50%;
		z-index: 3;
		width: 31%;
		height: 1.65rem;
		border-radius: 999px;
		background: oklch(0.025 0 0);
		transform: translateX(-50%);
		box-shadow: inset 0 0 0 1px oklch(1 0 0 / 0.035);
	}

	img {
		display: block;
		width: 100%;
		height: auto;
		border-radius: 2.7rem;
		background: oklch(0.04 0 0);
	}

	@media (max-width: 30rem) {
		.device__shell {
			border-radius: 2.55rem;
		}

		.device__shell::after,
		img {
			border-radius: 2.18rem;
		}

		.device__rail {
			border-radius: 2.2rem;
		}

		.device__island {
			top: 0.85rem;
			height: 1.3rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.device {
			filter: drop-shadow(0 1rem 1.5rem oklch(0% 0 0 / 0.34));
		}
	}
</style>
