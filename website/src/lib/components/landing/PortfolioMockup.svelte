<script lang="ts">
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import Plus from '@lucide/svelte/icons/plus';
	import { formatCurrency, formatPercent } from '$lib/format';
	import { m } from '$lib/paraglide/messages';
	import { getLocale } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
</script>

<div class="portfolio" aria-label={m.ui_portfolio()}>
	<header>
		<div><span>KARA</span><h3>{m.ui_portfolio()}</h3></div>
		<span class="mock-action" aria-hidden="true"><Plus size={16} /> {m.ui_add_item()}</span>
	</header>

	<div class="summary">
		<div class="main-value">
			<span>{m.ui_estimated_value()}</span>
			<strong class="tabular">{formatCurrency(24_860.4, locale, 2)}</strong>
			<small class="tabular"><ArrowUpRight size={13} aria-hidden="true" /> +{formatPercent(0.1828, locale, 2)} · +{formatCurrency(3_842.1, locale, 2)}</small>
		</div>
		<div class="secondary-values">
			<div><span>{m.ui_total_cost()}</span><strong class="tabular">{formatCurrency(21_018.3, locale, 2)}</strong></div>
			<div><span>{m.ui_objects()}</span><strong class="tabular">12</strong></div>
		</div>
	</div>

	<div class="chart" aria-label={`${m.ui_performance()}: +${formatPercent(0.1828, locale, 2)}`}>
		<div class="chart-label"><span>{m.ui_performance()}</span><span>{m.ui_last_twelve_months()}</span></div>
		<svg viewBox="0 0 760 170" role="img" aria-hidden="true" preserveAspectRatio="none">
			<defs>
				<linearGradient id="area" x1="0" y1="0" x2="0" y2="1">
					<stop offset="0" stop-color="oklch(0.56 0.18 258)" stop-opacity="0.4" />
					<stop offset="1" stop-color="oklch(0.56 0.18 258)" stop-opacity="0" />
				</linearGradient>
			</defs>
			<path class="area" d="M0 144 C54 132 72 146 118 124 S184 126 222 102 S290 113 329 86 S391 98 433 66 S502 75 545 48 S624 58 681 26 S731 28 760 10 L760 170 L0 170Z" />
			<path class="line" d="M0 144 C54 132 72 146 118 124 S184 126 222 102 S290 113 329 86 S391 98 433 66 S502 75 545 48 S624 58 681 26 S731 28 760 10" />
			<circle cx="760" cy="10" r="4" />
		</svg>
	</div>

	<div class="allocation">
		<div class="allocation-heading"><span>{m.ui_allocation()}</span><span>{m.ui_current_value()}</span></div>
		<div class="bar" aria-hidden="true"><span class="gold"></span><span class="silver"></span><span class="jewelry"></span></div>
		<div class="legend">
			<div><i class="gold"></i><span>{m.ui_gold()}</span><strong class="tabular">{formatPercent(0.68, locale)}</strong></div>
			<div><i class="silver"></i><span>{m.ui_silver()}</span><strong class="tabular">{formatPercent(0.21, locale)}</strong></div>
			<div><i class="jewelry"></i><span>{m.ui_jewelry()}</span><strong class="tabular">{formatPercent(0.11, locale)}</strong></div>
		</div>
	</div>
</div>

<style>
	.portfolio {
		width: min(100%, 49rem);
		padding: clamp(1rem, 3vw, 1.75rem);
		border-radius: 0.875rem;
		background: var(--color-surface);
		box-shadow: 0 8px 8px oklch(0 0 0 / 0.18);
		container-type: inline-size;
	}

	header,
	.mock-action,
	.summary,
	.main-value small,
	.secondary-values,
	.chart-label,
	.allocation-heading,
	.legend,
	.legend div {
		display: flex;
	}

	header,
	.summary,
	.chart-label,
	.allocation-heading {
		justify-content: space-between;
	}

	header {
		align-items: center;
		margin-bottom: clamp(2rem, 5vw, 3.5rem);
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

	.mock-action {
		align-items: center;
		gap: 0.4rem;
		min-height: 2.75rem;
		padding-inline: 0.85rem;
		border-radius: 999px;
		background: var(--color-cobalt);
		color: white;
		font-size: 0.7rem;
		font-weight: 580;
	}

	.summary {
		align-items: end;
		gap: 1.5rem;
	}

	.main-value > span,
	.secondary-values span,
	.chart-label,
	.allocation-heading,
	.legend {
		color: var(--color-muted);
		font-size: 0.7rem;
	}

	.main-value > strong {
		display: block;
		margin: 0.2rem 0 0.35rem;
		font-size: 3rem;
		font-weight: 400;
		letter-spacing: -0.04em;
		line-height: 1;
	}

	.main-value small {
		align-items: center;
		color: var(--color-positive);
		font-size: 0.72rem;
	}

	.secondary-values {
		gap: clamp(1rem, 4vw, 2.5rem);
	}

	.secondary-values span,
	.secondary-values strong {
		display: block;
	}

	.secondary-values strong {
		margin-top: 0.15rem;
		font-size: 0.85rem;
		font-weight: 500;
	}

	.chart {
		margin-top: 2rem;
	}

	.chart-label {
		margin-bottom: 0.65rem;
	}

	.chart svg {
		width: 100%;
		height: clamp(6.5rem, 22cqi, 10.5rem);
		overflow: visible;
	}

	.chart .area {
		fill: url(#area);
	}

	.chart .line {
		fill: none;
		stroke: var(--color-cobalt-bright);
		stroke-width: 2;
		vector-effect: non-scaling-stroke;
	}

	.chart circle {
		fill: var(--color-ink);
		stroke: var(--color-cobalt);
		stroke-width: 3;
	}

	.allocation {
		margin-top: 1.25rem;
		padding-top: 1rem;
		border-top: 1px solid var(--color-line);
	}

	.bar {
		display: flex;
		gap: 0.2rem;
		height: 0.38rem;
		margin: 0.8rem 0;
	}

	.bar span {
		display: block;
		border-radius: 999px;
	}

	.bar .gold { width: 68%; background: var(--color-gold); }
	.bar .silver { width: 21%; background: oklch(0.76 0.025 258); }
	.bar .jewelry { width: 11%; background: var(--color-cobalt-bright); }

	.legend {
		gap: 1.25rem;
		flex-wrap: wrap;
	}

	.legend div {
		align-items: center;
		gap: 0.38rem;
	}

	.legend i {
		width: 0.4rem;
		height: 0.4rem;
		border-radius: 50%;
	}

	.legend i.gold { background: var(--color-gold); }
	.legend i.silver { background: oklch(0.76 0.025 258); }
	.legend i.jewelry { background: var(--color-cobalt-bright); }
	.legend strong { color: var(--color-ink); font-weight: 500; }

	@container (max-width: 32rem) {
		.summary {
			align-items: start;
			flex-direction: column;
		}

		.secondary-values {
			width: 100%;
			justify-content: space-between;
		}

		.mock-action {
			width: 2.75rem;
			padding: 0;
			justify-content: center;
			font-size: 0;
		}

		.main-value > strong {
			font-size: 2.25rem;
		}
	}
</style>
