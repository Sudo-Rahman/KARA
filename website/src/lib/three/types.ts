export type SceneQuality = 'high' | 'mobile' | 'static';

export interface SceneReadyDetail {
	quality: SceneQuality;
}

export interface KaraSceneControllerOptions {
	quality?: SceneQuality;
	locale?: 'fr' | 'en';
	onReady?: (detail: SceneReadyDetail) => void;
	onError?: (error: Error) => void;
}

export interface KaraSceneController {
	mount(container: HTMLElement): boolean;
	setProgress(progress: number): void;
	resize(width?: number, height?: number): void;
	setQuality(quality: SceneQuality): void;
	destroy(): void;
}
