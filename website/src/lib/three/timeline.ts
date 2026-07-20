export const SCENE_CHAPTER_COUNT = 7;

export function normalizeSceneProgress(progress: number): number {
	if (!Number.isFinite(progress)) return 0;
	return Math.min(1, Math.max(0, progress));
}

/** Returns the local 0–1 progress for one of the seven landing-page chapters. */
export function getSceneChapterProgress(progress: number, chapterIndex: number): number {
	const normalized = normalizeSceneProgress(progress);
	const safeIndex = Math.min(SCENE_CHAPTER_COUNT - 1, Math.max(0, Math.trunc(chapterIndex)));
	const chapterStart = safeIndex / SCENE_CHAPTER_COUNT;
	return Math.min(1, Math.max(0, (normalized - chapterStart) * SCENE_CHAPTER_COUNT));
}
