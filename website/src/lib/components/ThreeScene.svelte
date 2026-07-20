<script lang="ts">
	import { onMount } from 'svelte';
	import { getLocale } from '$lib/paraglide/runtime';
	import { detectSceneQuality } from '$lib/three/quality';
	import type { KaraSceneController, SceneQuality, SceneReadyDetail } from '$lib/three/types';

	interface Props {
		progress?: number;
		quality?: SceneQuality | 'auto';
		class?: string;
		onready?: (detail: SceneReadyDetail) => void;
		onerror?: (error: Error) => void;
	}

	let {
		progress = 0,
		quality = 'auto',
		class: className = '',
		onready,
		onerror
	}: Props = $props();

	let host: HTMLDivElement;
	let controller = $state.raw<KaraSceneController | null>(null);
	let requestDynamicScene: ((quality: Exclude<SceneQuality, 'static'>) => void) | null = null;
	let resolvedQuality = $state<SceneQuality>('static');
	let webglReady = $state(false);

	$effect(() => {
		controller?.setProgress(progress);
	});

	$effect(() => {
		const nextQuality = quality === 'auto' ? detectSceneQuality() : quality;
		resolvedQuality = nextQuality;
		if (nextQuality === 'static') {
			webglReady = false;
			controller?.setQuality(nextQuality);
			return;
		}
		if (controller) controller.setQuality(nextQuality);
		else requestDynamicScene?.(nextQuality);
	});

	onMount(() => {
		const initialQuality = quality === 'auto' ? detectSceneQuality() : quality;
		resolvedQuality = initialQuality;
		const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
		const idleWindow = window as unknown as {
			requestIdleCallback?: typeof window.requestIdleCallback;
			cancelIdleCallback?: typeof window.cancelIdleCallback;
		};
		let resizeFrame: number | null = null;
		let instance: KaraSceneController | null = null;
		let disposed = false;
		let loading = false;
		let idleHandle: number | null = null;
		let fallbackTimer: number | null = null;

		const loadScene = (requestedQuality: Exclude<SceneQuality, 'static'>) => {
			if (instance) {
				instance.setQuality(requestedQuality);
				return;
			}
			if (loading || disposed) return;
			loading = true;

			void import('$lib/three/KaraSceneController')
				.then(async ({ createKaraSceneController }) => {
					if (disposed) return;
					await document.fonts.ready;
					await document.fonts.load('600 42px "Geologica Variable"');
					if (disposed) return;
					const mountQuality = quality === 'auto' ? detectSceneQuality() : quality;
					if (mountQuality === 'static') return;
					resolvedQuality = mountQuality;
					instance = createKaraSceneController({
						quality: mountQuality,
						locale: getLocale(),
						onReady: (detail) => {
							resolvedQuality = detail.quality;
							webglReady = detail.quality !== 'static';
							onready?.(detail);
						},
						onError: (error) => {
							resolvedQuality = 'static';
							webglReady = false;
							onerror?.(error);
						}
					});
					instance.setProgress(progress);
					instance.mount(host);
					controller = instance;
				})
				.catch((cause: unknown) => {
					if (disposed) return;
					const error = cause instanceof Error ? cause : new Error('Unable to load the Kara 3D scene');
					resolvedQuality = 'static';
					webglReady = false;
					onerror?.(error);
				})
				.finally(() => {
					loading = false;
				});
		};

		requestDynamicScene = loadScene;
		const beginInitialLoad = () => {
			if (disposed) return;
			if (idleHandle !== null && idleWindow.cancelIdleCallback) {
				idleWindow.cancelIdleCallback(idleHandle);
				idleHandle = null;
			}
			if (fallbackTimer !== null) {
				window.clearTimeout(fallbackTimer);
				fallbackTimer = null;
			}
			window.removeEventListener('pointerdown', beginInitialLoad);
			window.removeEventListener('scroll', beginInitialLoad);
			const currentQuality = quality === 'auto' ? detectSceneQuality() : quality;
			if (currentQuality !== 'static') loadScene(currentQuality);
		};

		const refreshAutomaticQuality = () => {
			if (quality !== 'auto') return;
			if (resizeFrame !== null) cancelAnimationFrame(resizeFrame);
			resizeFrame = requestAnimationFrame(() => {
				resizeFrame = null;
				const nextQuality = detectSceneQuality();
				resolvedQuality = nextQuality;
				if (nextQuality === 'static') webglReady = false;
				if (nextQuality === 'static') instance?.setQuality(nextQuality);
				else loadScene(nextQuality);
			});
		};

		reducedMotion.addEventListener('change', refreshAutomaticQuality);
		window.addEventListener('resize', refreshAutomaticQuality, { passive: true });

		if (initialQuality === 'static') {
			onready?.({ quality: 'static' });
		} else {
			window.addEventListener('pointerdown', beginInitialLoad, { once: true, passive: true });
			window.addEventListener('scroll', beginInitialLoad, { once: true, passive: true });
			if (idleWindow.requestIdleCallback) {
				idleHandle = idleWindow.requestIdleCallback(beginInitialLoad, { timeout: 1_800 });
			} else {
				fallbackTimer = window.setTimeout(beginInitialLoad, 800);
			}
		}

		return () => {
			disposed = true;
			if (resizeFrame !== null) cancelAnimationFrame(resizeFrame);
			if (idleHandle !== null && idleWindow.cancelIdleCallback) idleWindow.cancelIdleCallback(idleHandle);
			if (fallbackTimer !== null) window.clearTimeout(fallbackTimer);
			window.removeEventListener('pointerdown', beginInitialLoad);
			window.removeEventListener('scroll', beginInitialLoad);
			reducedMotion.removeEventListener('change', refreshAutomaticQuality);
			window.removeEventListener('resize', refreshAutomaticQuality);
			instance?.destroy();
			controller = null;
			requestDynamicScene = null;
		};
	});
</script>

<div
	bind:this={host}
	class={`kara-three-scene ${className}`}
	class:is-ready={webglReady}
	data-quality={resolvedQuality}
	data-progress={progress.toFixed(4)}
	aria-hidden="true"
>
	<div class="kara-three-scene__poster">
		<span class="kara-three-scene__halo"></span>
		<span class="kara-three-scene__vault kara-three-scene__vault--outer"></span>
		<span class="kara-three-scene__vault kara-three-scene__vault--inner"></span>
		<span class="kara-three-scene__bar"><span>KARA</span></span>
	</div>
</div>

<style>
	.kara-three-scene {
		position: absolute;
		inset: 0;
		isolation: isolate;
		overflow: hidden;
		pointer-events: none;
		contain: layout paint;
	}

	.kara-three-scene__poster {
		position: absolute;
		inset: 0;
		overflow: hidden;
		background:
			radial-gradient(circle at 22% 31%, color-mix(in oklab, #285aff 20%, transparent), transparent 28%),
			radial-gradient(circle at 55% 53%, rgba(21, 31, 70, 0.42), transparent 44%);
		opacity: 1;
		transition: opacity 700ms cubic-bezier(0.16, 1, 0.3, 1);
	}

	.is-ready .kara-three-scene__poster {
		opacity: 0;
	}

	.kara-three-scene__halo,
	.kara-three-scene__vault,
	.kara-three-scene__bar {
		position: absolute;
		left: 50%;
		top: 50%;
		transform: translate(-50%, -50%);
	}

	.kara-three-scene__halo {
		width: min(74vw, 52rem);
		aspect-ratio: 1;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(42, 91, 255, 0.16), transparent 66%);
		filter: blur(12px);
	}

	.kara-three-scene__vault {
		aspect-ratio: 1;
		border: 1px solid rgba(78, 110, 199, 0.2);
		border-radius: 50%;
		box-shadow:
			inset 0 0 4rem rgba(48, 82, 184, 0.08),
			0 0 3rem rgba(36, 77, 200, 0.08);
	}

	.kara-three-scene__vault--outer {
		width: min(66vw, 43rem);
	}

	.kara-three-scene__vault--inner {
		width: min(53vw, 34rem);
		border-color: rgba(102, 139, 246, 0.12);
	}

	.kara-three-scene__bar {
		left: 68%;
		display: grid;
		width: min(32vw, 20.5rem);
		aspect-ratio: 1.94;
		place-items: center;
		border: 1px solid rgba(255, 228, 161, 0.52);
		border-radius: 12%;
		background:
			linear-gradient(145deg, rgba(255, 237, 182, 0.96), rgba(196, 133, 33, 0.94) 48%, rgba(101, 61, 9, 0.97)),
			#d5a33e;
		box-shadow:
			inset 0 1px 1px rgba(255, 252, 222, 0.8),
			0 2rem 5rem rgba(0, 0, 0, 0.42),
			-1rem -0.5rem 3rem rgba(50, 96, 255, 0.13);
		transform: translate(-50%, -50%) perspective(900px) rotateX(8deg) rotateY(-18deg) rotateZ(-2deg);
	}

	.kara-three-scene__bar span {
		font-family: Georgia, 'Times New Roman', serif;
		font-size: clamp(1.3rem, 3vw, 2.7rem);
		font-weight: 700;
		letter-spacing: 0.16em;
		color: rgba(65, 39, 7, 0.82);
		text-shadow: 0 1px 0 rgba(255, 230, 161, 0.46);
	}

	@media (min-width: 48rem) and (max-width: 68.75rem) {
		.kara-three-scene__bar {
			left: 80%;
			width: min(24vw, 16rem);
		}
	}

	@media (max-width: 47.99rem) {
		.kara-three-scene__poster {
			background:
				radial-gradient(circle at 50% 64%, color-mix(in oklab, #285aff 18%, transparent), transparent 35%),
				radial-gradient(circle at 50% 60%, rgba(21, 31, 70, 0.38), transparent 48%);
		}

		.kara-three-scene__halo,
		.kara-three-scene__vault,
		.kara-three-scene__bar {
			top: 62%;
		}

		.kara-three-scene__bar {
			left: 50%;
		}

		.kara-three-scene__halo {
			width: 110vw;
		}

		.kara-three-scene__vault--outer {
			width: 92vw;
		}

		.kara-three-scene__vault--inner {
			width: 72vw;
		}

		.kara-three-scene__bar {
			width: min(62vw, 18rem);
		}
	}

	@media (max-height: 35rem) and (orientation: landscape) {
		.kara-three-scene__halo,
		.kara-three-scene__vault,
		.kara-three-scene__bar {
			top: 54%;
		}

		.kara-three-scene__bar {
			width: min(31vw, 15rem);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.kara-three-scene__poster {
			transition: none;
		}
	}
</style>
