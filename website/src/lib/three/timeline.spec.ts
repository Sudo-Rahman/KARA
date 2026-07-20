import { describe, expect, it } from 'vitest';
import { getSceneChapterProgress, normalizeSceneProgress, SCENE_CHAPTER_COUNT } from './timeline';

describe('scene timeline', () => {
	it('normalizes arbitrary scroll values to the 0–1 scene interval', () => {
		expect(normalizeSceneProgress(-2)).toBe(0);
		expect(normalizeSceneProgress(0.42)).toBe(0.42);
		expect(normalizeSceneProgress(4)).toBe(1);
		expect(normalizeSceneProgress(Number.NaN)).toBe(0);
	});

	it('maps each landing chapter to its own normalized interval', () => {
		const chapter = 3;
		expect(getSceneChapterProgress(chapter / SCENE_CHAPTER_COUNT, chapter)).toBe(0);
		expect(getSceneChapterProgress((chapter + 0.5) / SCENE_CHAPTER_COUNT, chapter)).toBeCloseTo(0.5);
		expect(getSceneChapterProgress((chapter + 1) / SCENE_CHAPTER_COUNT, chapter)).toBe(1);
	});
});
