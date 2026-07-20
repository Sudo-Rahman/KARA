<script lang="ts">
	import ArrowRight from '@lucide/svelte/icons/arrow-right';
	import Sparkles from '@lucide/svelte/icons/sparkles';
	import { formatCurrency, formatPercent } from '$lib/format';
	import { m } from '$lib/paraglide/messages';
	import { getLocale } from '$lib/paraglide/runtime';

	let share = $state(62);
	const acquisition = 21018.3;
	const current = 24860.4;
	const saleValue = $derived(current * (share / 100));
	const saleCost = $derived(acquisition * (share / 100));
	const gain = $derived(saleValue - saleCost);
	const locale = $derived(getLocale());
</script>

<div class="simulator">
	<header>
		<div><span>KARA</span><h3>{m.ui_simulate()}</h3></div>
		<Sparkles class="sparkle-icon" size={18} strokeWidth={1.6} aria-hidden="true" />
	</header>

	<div class="comparison">
		<div class="metric">
			<span>{m.ui_total_cost()}</span>
			<strong class="tabular">{formatCurrency(saleCost, locale)}</strong>
		</div>
		<ArrowRight class="comparison-arrow" size={18} aria-hidden="true" />
		<div class="metric current">
			<span>{m.ui_sale_amount()}</span>
			<strong class="tabular">{formatCurrency(saleValue, locale)}</strong>
		</div>
	</div>

	<div class="gain">
		<span>{m.ui_gain()}</span>
		<strong class="tabular">+{formatCurrency(gain, locale)}</strong>
	</div>

	<label for="sale-share">
		<span>{m.ui_sell_share()}</span>
		<output for="sale-share" class="tabular">{formatPercent(share / 100, locale)}</output>
	</label>
	<input id="sale-share" type="range" min="10" max="100" step="1" bind:value={share} />
	<div class="range-labels tabular" aria-hidden="true"><span>{formatPercent(0.1, locale)}</span><span>{formatPercent(1, locale)}</span></div>
</div>

<style>
	.simulator {
		width: min(100%, 38rem);
		padding: clamp(1rem, 4vw, 1.75rem);
		border: 1px solid var(--color-line);
		border-radius: 0.875rem;
		background: var(--color-surface);
		font-variant-numeric: tabular-nums lining-nums;
	}

	header,
	.comparison,
	.gain,
	label,
	.range-labels {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	header {
		margin-bottom: clamp(2.5rem, 8vw, 5rem);
	}

	header > div > span {
		display: block;
		color: var(--color-cobalt-bright);
		font-family: Georgia, serif;
		font-size: 0.55rem;
		letter-spacing: 0.13em;
	}

	header h3 {
		font-size: 1rem;
		font-weight: 490;
	}

	header :global(.sparkle-icon) {
		color: var(--color-gold);
	}

	.comparison {
		gap: 1rem;
		padding-bottom: 1.25rem;
		border-bottom: 1px solid var(--color-line);
	}

	.comparison :global(.comparison-arrow) {
		flex: 0 0 auto;
		color: var(--color-subtle);
	}

	.metric {
		min-width: 0;
	}

	.metric span,
	.gain span,
	label,
	.range-labels {
		color: var(--color-muted);
		font-size: 0.7rem;
	}

	.metric strong {
		display: block;
		margin-top: 0.3rem;
		font-size: 2rem;
		font-weight: 430;
		letter-spacing: -0.03em;
	}

	.metric.current {
		text-align: right;
	}

	.metric.current strong {
		color: var(--color-ink);
	}

	.gain {
		margin: 1.25rem 0 2.5rem;
	}

	.gain strong {
		color: var(--color-positive);
		font-size: 1.1rem;
		font-weight: 560;
	}

	label {
		margin-bottom: 0.75rem;
	}

	output {
		color: var(--color-ink);
		font-weight: 560;
	}

	input[type='range'] {
		width: 100%;
		height: 2.75rem;
		margin: 0;
		accent-color: var(--color-cobalt-bright);
		cursor: pointer;
	}

	.range-labels {
		margin-top: -0.4rem;
		font-size: 0.7rem;
	}

	@media (max-width: 28rem) {
		.comparison {
			align-items: stretch;
			flex-direction: column;
		}

		.comparison :global(.comparison-arrow) {
			transform: rotate(90deg);
		}

		.metric.current {
			text-align: left;
		}
	}
</style>
