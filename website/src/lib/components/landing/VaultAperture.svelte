<script lang="ts">
	const bolts = Array.from({ length: 12 }, (_, index) => {
		const angle = (index * Math.PI * 2) / 12;
		return {
			left: 50 + Math.sin(angle) * 42,
			top: 50 - Math.cos(angle) * 42
		};
	});
</script>

<div class="vault-aperture" aria-hidden="true">
	<div class="vault-aperture__halo"></div>
	<div class="vault-aperture__outer">
		<div class="vault-aperture__ticks"></div>
		{#each bolts as bolt}
			<span
				class="vault-aperture__bolt"
				style={`left: ${bolt.left}%; top: ${bolt.top}%`}
			></span>
		{/each}
		<div class="vault-aperture__inner">
			<div class="vault-aperture__well"></div>
		</div>
	</div>
	<div class="vault-aperture__hinge">
		<span></span>
		<span></span>
		<span></span>
	</div>
</div>

<style>
	.vault-aperture {
		position: relative;
		width: 100%;
		aspect-ratio: 1;
		isolation: isolate;
	}

	.vault-aperture__halo {
		position: absolute;
		inset: 5%;
		border-radius: 50%;
		background: oklch(0.56 0.22 258 / 0.2);
		filter: blur(3rem);
		transform: scale(1.08);
	}

	.vault-aperture__outer {
		position: absolute;
		inset: 7%;
		border-radius: 50%;
		background:
			radial-gradient(circle at 35% 24%, oklch(0.31 0.035 258), transparent 16%),
			conic-gradient(
				from 12deg,
				oklch(0.15 0.014 258),
				oklch(0.26 0.028 258) 7%,
				oklch(0.11 0.01 258) 16%,
				oklch(0.24 0.025 258) 23%,
				oklch(0.12 0.01 258) 34%,
				oklch(0.3 0.032 258) 46%,
				oklch(0.12 0.01 258) 61%,
				oklch(0.25 0.027 258) 74%,
				oklch(0.1 0.008 258) 87%,
				oklch(0.15 0.014 258)
			);
		box-shadow:
			inset 0 0 0 1px oklch(0.72 0.15 258 / 0.32),
			inset 0 0 0 0.55rem oklch(0.04 0.004 258 / 0.8),
			inset 0 0 2rem oklch(0.56 0.2 258 / 0.18),
			0 0 0 1px oklch(0.72 0.15 258 / 0.16);
	}

	.vault-aperture__ticks {
		position: absolute;
		inset: 7%;
		border-radius: 50%;
		background: repeating-conic-gradient(
			from 0deg,
			oklch(0.72 0.15 258 / 0.5) 0deg 0.45deg,
			transparent 0.45deg 10deg
		);
		-webkit-mask: radial-gradient(transparent 0 82%, #000 82.2% 84%, transparent 84.2%);
		mask: radial-gradient(transparent 0 82%, #000 82.2% 84%, transparent 84.2%);
	}

	.vault-aperture__inner {
		position: absolute;
		inset: 15%;
		display: grid;
		place-items: center;
		border-radius: 50%;
		background: oklch(0.045 0.01 258);
		box-shadow:
			0 0 0 1px oklch(0.72 0.15 258 / 0.5),
			0 0 0 0.4rem oklch(0.08 0.03 258),
			0 0 0 0.55rem oklch(0.56 0.2 258 / 0.28),
			inset 0 0 3rem oklch(0 0 0 / 0.9);
	}

	.vault-aperture__well {
		width: 88%;
		aspect-ratio: 1;
		border-radius: 50%;
		background:
			radial-gradient(circle at 52% 45%, oklch(0.46 0.22 258 / 0.42), transparent 26%),
			radial-gradient(circle at 50% 50%, oklch(0.16 0.08 258), oklch(0.035 0.01 258) 72%);
		box-shadow: inset 0 0 5rem oklch(0 0 0 / 0.88);
	}

	.vault-aperture__bolt {
		position: absolute;
		width: clamp(0.42rem, 1vw, 0.72rem);
		aspect-ratio: 1;
		border-radius: 50%;
		background: radial-gradient(
			circle at 36% 30%,
			oklch(0.62 0.04 258),
			oklch(0.17 0.018 258) 54%,
			oklch(0.05 0.005 258)
		);
		box-shadow: 0 0 0 1px oklch(0.72 0.15 258 / 0.32);
		transform: translate(-50%, -50%);
	}

	.vault-aperture__hinge {
		position: absolute;
		top: 24%;
		left: 2%;
		z-index: -1;
		display: flex;
		width: 16%;
		height: 52%;
		flex-direction: column;
		justify-content: space-between;
	}

	.vault-aperture__hinge::before {
		position: absolute;
		inset: 10% 36%;
		border-radius: 999px;
		background: linear-gradient(
			90deg,
			oklch(0.07 0.008 258),
			oklch(0.32 0.034 258),
			oklch(0.08 0.008 258)
		);
		content: '';
	}

	.vault-aperture__hinge span {
		z-index: 1;
		height: 23%;
		border-radius: 0.45rem;
		background: linear-gradient(
			135deg,
			oklch(0.28 0.032 258),
			oklch(0.1 0.01 258) 45%,
			oklch(0.2 0.023 258)
		);
		box-shadow: inset 0 0 0 1px oklch(0.72 0.15 258 / 0.26);
	}
</style>
