<script lang="ts">
	import Download from '@lucide/svelte/icons/download';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import { formatCurrency, formatPercent, formatReportDate } from '$lib/format';
	import { m } from '$lib/paraglide/messages';
	import { getLocale } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
</script>

<div class="report-wrap">
	<div class="report-sheet" aria-label={m.ui_report()}>
		<header>
			<div class="report-mark">KARA</div>
			<div class="date tabular">{formatReportDate(locale)}</div>
		</header>
		<div class="report-title"><span>{m.ui_report()}</span><strong class="tabular">{formatCurrency(24_860.4, locale, 2)}</strong></div>
		<div class="report-grid">
			<div><span>{m.ui_total_cost()}</span><strong class="tabular">{formatCurrency(21_018.3, locale, 2)}</strong></div>
			<div><span>{m.ui_performance()}</span><strong class="positive tabular">+{formatPercent(0.1828, locale, 2)}</strong></div>
			<div><span>{m.ui_objects()}</span><strong class="tabular">12</strong></div>
		</div>
		<div class="table" aria-hidden="true">
			<div class="table-head"><span>{m.ui_item()}</span><span>{m.ui_purchase_short()}</span><span>{m.ui_value()}</span></div>
			<div><span>{m.ui_gold_bar()}</span><span>{formatCurrency(12_480, locale)}</span><span>{formatCurrency(15_920, locale)}</span></div>
			<div><span>{m.ui_silver_coin()}</span><span>{formatCurrency(31, locale)}</span><span>{formatCurrency(42, locale)}</span></div>
			<div><span>{m.ui_ring()}</span><span>{formatCurrency(510, locale)}</span><span>{formatCurrency(680, locale)}</span></div>
		</div>
		<footer><ShieldCheck size={13} aria-hidden="true" /> {m.ui_generated_locally()}</footer>
	</div>
	<span class="mock-action" aria-hidden="true"><Download size={16} /> {m.ui_export_pdf()}</span>
</div>

<style>
	.report-wrap {
		position: relative;
		width: min(100%, 36rem);
		padding-bottom: 1.5rem;
	}

	.report-sheet {
		padding: clamp(1.25rem, 5vw, 2.5rem);
		border-radius: 0.5rem;
		background: oklch(0.955 0.005 95);
		box-shadow: 0 8px 8px oklch(0 0 0 / 0.19);
		color: oklch(0.17 0.015 258);
		font-variant-numeric: tabular-nums lining-nums;
		transform: perspective(60rem) rotateY(-4deg) rotateX(2deg);
		transform-origin: center;
	}

	header,
	.report-title,
	.report-grid,
	.table > div,
	footer,
	.mock-action {
		display: flex;
	}

	header,
	.report-title {
		align-items: center;
		justify-content: space-between;
	}

	header {
		padding-bottom: 1.2rem;
		border-bottom: 1px solid oklch(0.78 0.012 258);
	}

	.report-mark {
		font-family: Georgia, serif;
		font-size: 0.8rem;
		letter-spacing: 0.15em;
	}

	.date,
	.report-title span,
	.report-grid span,
	.table,
	footer {
		font-size: 0.68rem;
	}

	.date,
	.report-title span,
	.report-grid span,
	.table-head,
	footer {
		color: oklch(0.48 0.014 258);
	}

	.report-title {
		gap: 1rem;
		padding: clamp(1.5rem, 5vw, 3rem) 0;
	}

	.report-title strong {
		font-size: 2.5rem;
		font-weight: 430;
		letter-spacing: -0.04em;
	}

	.report-grid {
		grid-template-columns: repeat(3, 1fr);
		gap: 1rem;
		padding-bottom: 1.5rem;
		border-bottom: 1px solid oklch(0.78 0.012 258);
	}

	.report-grid div {
		min-width: 0;
	}

	.report-grid span,
	.report-grid strong {
		display: block;
	}

	.report-grid strong {
		margin-top: 0.2rem;
		font-size: 0.78rem;
		font-weight: 540;
	}

	.report-grid .positive {
		color: oklch(0.43 0.13 153);
	}

	.table {
		margin-top: 1.5rem;
	}

	.table > div {
		grid-template-columns: 1.4fr 0.8fr 0.8fr;
		gap: 0.75rem;
		padding: 0.55rem 0;
		border-bottom: 1px solid oklch(0.84 0.009 258);
	}

	.table span:nth-child(n + 2) {
		text-align: right;
	}

	footer {
		align-items: center;
		gap: 0.35rem;
		margin-top: 1.25rem;
	}

	.mock-action {
		position: absolute;
		right: clamp(1rem, 4vw, 2rem);
		bottom: 0;
		align-items: center;
		gap: 0.45rem;
		min-height: 2.75rem;
		padding-inline: 1rem;
		border-radius: 999px;
		background: var(--color-cobalt);
		color: white;
		font-size: 0.68rem;
		font-weight: 590;
		box-shadow: 0 6px 8px oklch(0 0 0 / 0.22);
	}

	@media (max-width: 28rem) {
		.report-sheet {
			transform: none;
		}

		.report-title {
			align-items: start;
			flex-direction: column;
		}

		.report-title strong {
			font-size: 2rem;
		}

		.report-grid {
			grid-template-columns: 1fr 1fr;
			flex-wrap: wrap;
		}

		.table span:nth-child(2) {
			display: none;
		}

		.table > div {
			grid-template-columns: 1fr auto;
		}
	}
</style>
