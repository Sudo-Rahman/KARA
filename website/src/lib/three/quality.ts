import type { SceneQuality } from './types';

export interface SceneQualityEnvironment {
	width: number;
	height: number;
	devicePixelRatio: number;
	reducedMotion: boolean;
	saveData: boolean;
	webgl: boolean;
}

export interface SceneQualitySettings {
	antialias: boolean;
	maxDpr: number;
	shadows: boolean;
	targetFps: number;
}

export const sceneQualitySettings = {
	high: {
		antialias: true,
		maxDpr: 1.8,
		shadows: true,
		targetFps: 60
	},
	mobile: {
		antialias: false,
		maxDpr: 1.25,
		shadows: false,
		targetFps: 30
	},
	static: {
		antialias: false,
		maxDpr: 1,
		shadows: false,
		targetFps: 0
	}
} satisfies Record<SceneQuality, SceneQualitySettings>;

/** Pure quality selection used by both the component and unit tests. */
export function chooseSceneQuality(environment: SceneQualityEnvironment): SceneQuality {
	if (!environment.webgl || environment.reducedMotion || environment.saveData) return 'static';

	const compactViewport = environment.width < 1024;
	const portraitTablet = environment.width < 1180 && environment.height > environment.width;
	const veryDenseCompactDisplay = environment.devicePixelRatio > 2 && environment.width < 1280;

	return compactViewport || portraitTablet || veryDenseCompactDisplay ? 'mobile' : 'high';
}

export function supportsWebGL(): boolean {
	if (typeof document === 'undefined') return false;

	try {
		const canvas = document.createElement('canvas');
		return Boolean(
			canvas.getContext('webgl2', { failIfMajorPerformanceCaveat: true }) ??
				canvas.getContext('webgl', { failIfMajorPerformanceCaveat: true })
		);
	} catch {
		return false;
	}
}

export function detectSceneQuality(): SceneQuality {
	if (typeof window === 'undefined') return 'static';

	type NavigatorWithConnection = Navigator & {
		connection?: { saveData?: boolean };
	};

	const navigatorWithConnection = window.navigator as NavigatorWithConnection;

	return chooseSceneQuality({
		width: window.innerWidth,
		height: window.innerHeight,
		devicePixelRatio: window.devicePixelRatio || 1,
		reducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
		saveData: navigatorWithConnection.connection?.saveData === true,
		webgl: supportsWebGL()
	});
}
