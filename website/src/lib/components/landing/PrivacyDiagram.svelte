<script lang="ts">
	import Cloud from '@lucide/svelte/icons/cloud';
	import CloudOff from '@lucide/svelte/icons/cloud-off';
	import HardDrive from '@lucide/svelte/icons/hard-drive';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import { m } from '$lib/paraglide/messages';
</script>

<div class="privacy-diagram" role="img" aria-label={`${m.ui_device()}, ${m.ui_private_space()}, ${m.ui_no_kara_server()}`}>
	<div class="orbit" aria-hidden="true"></div>
	<div class="node device">
		<div class="icon"><Smartphone size={26} strokeWidth={1.5} aria-hidden="true" /></div>
		<span>{m.ui_device()}</span>
		<small><HardDrive size={12} aria-hidden="true" /> {m.ui_local()}</small>
	</div>
	<div class="connector one" aria-hidden="true"><span></span></div>
	<div class="node private-space">
		<div class="icon"><Cloud size={26} strokeWidth={1.5} aria-hidden="true" /></div>
		<span>{m.ui_private_space()}</span>
		<small><ShieldCheck size={12} aria-hidden="true" /> iCloud · Google</small>
	</div>
	<div class="connector blocked" aria-hidden="true"><span></span></div>
	<div class="node no-server">
		<div class="icon"><CloudOff size={26} strokeWidth={1.5} aria-hidden="true" /></div>
		<span>{m.ui_no_kara_server()}</span>
		<small>{m.ui_zero_asset_data()}</small>
	</div>
</div>

<style>
	.privacy-diagram {
		position: relative;
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		align-items: center;
		gap: clamp(0.75rem, 3vw, 2rem);
		width: min(100%, 52rem);
		min-height: 21rem;
		padding: clamp(1rem, 4vw, 2rem);
		border: 1px solid oklch(0.38 0.05 258);
		border-radius: 0.875rem;
		background: oklch(0.11 0.025 258 / 0.94);
		box-shadow: 0 8px 8px oklch(0 0 0 / 0.18);
		isolation: isolate;
	}

	.orbit {
		position: absolute;
		z-index: -1;
		inset: 12% 8%;
		border-radius: 50%;
		background: radial-gradient(circle at 35% 50%, oklch(0.56 0.18 258 / 0.26), transparent 42%);
		filter: blur(2rem);
	}

	.node {
		position: relative;
		display: flex;
		align-items: center;
		flex-direction: column;
		min-width: 0;
		text-align: center;
	}

	.icon {
		display: grid;
		place-items: center;
		width: 4rem;
		height: 4rem;
		margin-bottom: 0.8rem;
		border-radius: 50%;
		background: var(--color-surface-raised);
		color: var(--color-cobalt-bright);
	}

	.device .icon {
		background: var(--color-cobalt);
		color: white;
	}

	.no-server .icon {
		border: 1px solid oklch(0.6 0.1 24);
		background: oklch(0.23 0.06 24);
		color: oklch(0.8 0.11 24);
	}

	.node > span {
		font-size: 0.78rem;
		font-weight: 550;
	}

	.node small {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		margin-top: 0.25rem;
		color: var(--color-muted);
		font-size: 0.68rem;
	}

	.connector {
		position: absolute;
		top: 50%;
		height: 1px;
		transform: translateY(-2rem);
	}

	.connector.one {
		left: 24%;
		width: 19%;
		background: linear-gradient(90deg, var(--color-cobalt-bright), var(--color-cobalt));
	}

	.connector.blocked {
		left: 57%;
		width: 19%;
		background: repeating-linear-gradient(90deg, var(--color-subtle) 0 0.5rem, transparent 0.5rem 0.85rem);
	}

	.connector.blocked::after {
		content: '';
		position: absolute;
		top: 50%;
		left: 50%;
		width: 1.4rem;
		height: 1px;
		background: oklch(0.8 0.11 24);
		transform: translate(-50%, -50%) rotate(-48deg);
	}

	@media (max-width: 38rem) {
		.privacy-diagram {
			grid-template-columns: 1fr;
			gap: 2.25rem;
			min-height: 31rem;
		}

		.connector {
			left: 50% !important;
			width: 1px !important;
			height: 3rem;
			transform: translateX(-50%);
		}

		.connector.one {
			top: 29%;
			background: linear-gradient(var(--color-cobalt-bright), var(--color-cobalt));
		}

		.connector.blocked {
			top: 62%;
			background: repeating-linear-gradient(var(--color-subtle) 0 0.5rem, transparent 0.5rem 0.85rem);
		}
	}
</style>
