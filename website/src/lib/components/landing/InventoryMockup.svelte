<script lang="ts">
	import MapPin from '@lucide/svelte/icons/map-pin';
	import Plus from '@lucide/svelte/icons/plus';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import TrendingUp from '@lucide/svelte/icons/trending-up';
	import { formatCurrency, formatNumber } from '$lib/format';
	import { m } from '$lib/paraglide/messages';
	import { getLocale } from '$lib/paraglide/runtime';

	const locale = $derived(getLocale());
</script>

<div class="app-window inventory-window" aria-label={m.ui_inventory()}>
	<div class="app-topbar">
		<div>
			<span class="app-caption">KARA</span>
			<h3>{m.ui_inventory()}</h3>
		</div>
		<span class="mock-action" aria-hidden="true">
			<Plus size={17} strokeWidth={2} aria-hidden="true" />
		</span>
	</div>

	<div class="inventory-layout">
		<div class="object-list" role="list" aria-label={m.ui_objects()}>
			<div class="object-row selected" role="listitem">
				<div class="object-icon gold"><span></span></div>
				<div><strong>{m.ui_gold_bar()}</strong><small>250 g · {formatNumber(999.9, locale, 1)} ‰</small></div>
				<span class="value tabular">{formatCurrency(15_920, locale)}</span>
			</div>
			<div class="object-row" role="listitem">
				<div class="object-icon silver"><span></span></div>
				<div><strong>{m.ui_silver_coin()}</strong><small>25 g · 900 ‰</small></div>
				<span class="value tabular">{formatCurrency(42, locale)}</span>
			</div>
			<div class="object-row" role="listitem">
				<div class="object-icon ring"><span></span></div>
				<div><strong>{m.ui_ring()}</strong><small>{formatNumber(8.2, locale, 1)} g · 750 ‰</small></div>
				<span class="value tabular">{formatCurrency(680, locale)}</span>
			</div>
		</div>

		<div class="object-detail">
			<div class="detail-visual" aria-hidden="true">
				<div class="mini-ingot">KARA</div>
			</div>
			<div class="detail-heading">
				<div><span>{m.ui_gold()}</span><h3>{m.ui_gold_bar()}</h3></div>
				<span class="verified"><ShieldCheck size={14} aria-hidden="true" /> {formatNumber(999.9, locale, 1)} ‰</span>
			</div>
			<dl>
				<div><dt>{m.ui_weight()}</dt><dd class="tabular">250 g</dd></div>
				<div><dt>{m.ui_purchase_price()}</dt><dd class="tabular">{formatCurrency(12_480, locale)}</dd></div>
				<div><dt>{m.ui_location()}</dt><dd><MapPin size={13} aria-hidden="true" /> {m.ui_location_value()}</dd></div>
				<div><dt>{m.ui_current_value()}</dt><dd class="tabular"><TrendingUp size={13} aria-hidden="true" /> {formatCurrency(15_920, locale)}</dd></div>
			</dl>
		</div>
	</div>
</div>

<style>
	.app-window {
		width: min(100%, 48rem);
		overflow: hidden;
		border: 1px solid var(--color-line);
		border-radius: 0.875rem;
		background: oklch(0.105 0.01 258 / 0.96);
		color: var(--color-ink);
		container-type: inline-size;
	}

	.app-topbar,
	.inventory-layout,
	.object-row,
	.detail-heading,
	dl > div,
	.object-row > div:nth-child(2),
	.verified,
	dd {
		display: flex;
	}

	.app-topbar {
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1rem 0.875rem;
		border-bottom: 1px solid oklch(0.29 0.018 258 / 0.76);
	}

	.app-caption {
		display: block;
		margin-bottom: 0.1rem;
		color: var(--color-cobalt-bright);
		font-family: Georgia, serif;
		font-size: 0.55rem;
		letter-spacing: 0.13em;
	}

	.app-topbar h3,
	.detail-heading h3 {
		font-weight: 490;
	}

	.app-topbar h3 {
		font-size: 0.95rem;
	}

	.mock-action {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border-radius: 50%;
		background: var(--color-cobalt);
	}

	.inventory-layout {
		min-height: 25rem;
	}

	.object-list {
		width: 45%;
		padding: 0.75rem;
		border-right: 1px solid oklch(0.29 0.018 258 / 0.76);
	}

	.object-row {
		position: relative;
		align-items: center;
		gap: 0.75rem;
		min-height: 4.75rem;
		padding: 0.75rem;
		border-radius: 0.65rem;
	}

	.object-row.selected {
		background: oklch(0.18 0.03 258);
	}

	.object-row > div:nth-child(2) {
		min-width: 0;
		flex: 1;
		flex-direction: column;
	}

	.object-row strong,
	.object-row small {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.object-row strong {
		font-size: 0.72rem;
		font-weight: 500;
	}

	.object-row small {
		color: var(--color-muted);
		font-size: 0.68rem;
	}

	.object-row .value {
		font-size: 0.7rem;
		font-weight: 540;
	}

	.object-icon {
		display: grid;
		place-items: center;
		width: 2.35rem;
		height: 2.35rem;
		flex: 0 0 auto;
		border-radius: 0.55rem;
		background: var(--color-surface-raised);
	}

	.object-icon span {
		display: block;
	}

	.object-icon.gold span {
		width: 1.35rem;
		height: 0.75rem;
		border-radius: 0.2rem;
		background: linear-gradient(135deg, var(--color-gold-bright), var(--color-gold));
		transform: perspective(80px) rotateX(35deg);
	}

	.object-icon.silver span {
		width: 1.15rem;
		height: 1.15rem;
		border: 2px solid oklch(0.78 0.015 258);
		border-radius: 50%;
	}

	.object-icon.ring span {
		width: 1.2rem;
		height: 1.2rem;
		border: 0.22rem solid var(--color-gold);
		border-radius: 50%;
	}

	.object-detail {
		width: 55%;
		padding: 1rem;
	}

	.detail-visual {
		position: relative;
		display: grid;
		place-items: center;
		height: 10.5rem;
		margin-bottom: 1.15rem;
		overflow: hidden;
		border-radius: 0.75rem;
		background: radial-gradient(circle at 50% 42%, oklch(0.43 0.14 258), oklch(0.13 0.025 258) 55%, var(--color-void) 100%);
	}

	.mini-ingot {
		display: grid;
		place-items: center;
		width: 54%;
		aspect-ratio: 1.7;
		border-radius: 0.55rem;
		background: linear-gradient(145deg, var(--color-gold-bright), oklch(0.64 0.13 73) 45%, var(--color-gold) 62%, oklch(0.43 0.1 70));
		color: oklch(0.34 0.08 73);
		font-family: Georgia, serif;
		font-size: 0.8rem;
		letter-spacing: 0.12em;
		transform: perspective(18rem) rotateX(52deg) rotateZ(-8deg);
		box-shadow: 0 0.75rem 1rem oklch(0 0 0 / 0.35), inset 0 1px 0 var(--color-gold-bright);
	}

	.detail-heading {
		align-items: start;
		justify-content: space-between;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.detail-heading span:first-child {
		color: var(--color-muted);
		font-size: 0.68rem;
	}

	.detail-heading h3 {
		font-size: 0.88rem;
	}

	.verified {
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.45rem;
		border-radius: 999px;
		background: oklch(0.76 0.13 153 / 0.14);
		color: var(--color-positive);
		font-size: 0.68rem;
		white-space: nowrap;
	}

	dl {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 0.75rem;
		margin: 0;
	}

	dl > div {
		min-width: 0;
		flex-direction: column;
		gap: 0.15rem;
	}

	dt {
		color: var(--color-muted);
		font-size: 0.68rem;
	}

	dd {
		align-items: center;
		gap: 0.25rem;
		margin: 0;
		font-size: 0.72rem;
	}

	@container (max-width: 34rem) {
		.inventory-layout {
			min-height: 30rem;
			flex-direction: column-reverse;
		}

		.object-list,
		.object-detail {
			width: 100%;
		}

		.object-list {
			display: grid;
			grid-template-columns: repeat(3, minmax(0, 1fr));
			border-top: 1px solid oklch(0.29 0.018 258 / 0.76);
			border-right: 0;
		}

		.object-row {
			min-width: 0;
			padding: 0.5rem;
		}

		.object-row > div:nth-child(2),
		.object-row .value {
			display: none;
		}

		.detail-visual {
			height: 9rem;
		}
	}
</style>
