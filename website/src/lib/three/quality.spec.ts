import { describe, expect, it } from 'vitest';
import { chooseSceneQuality } from './quality';

const desktop = {
	width: 1440,
	height: 900,
	devicePixelRatio: 2,
	reducedMotion: false,
	saveData: false,
	webgl: true
};

describe('chooseSceneQuality', () => {
	it('uses the high profile on capable desktop viewports', () => {
		expect(chooseSceneQuality(desktop)).toBe('high');
	});

	it('keeps the full scene with a mobile rendering budget on compact screens', () => {
		expect(chooseSceneQuality({ ...desktop, width: 390, height: 844, devicePixelRatio: 3 })).toBe(
			'mobile'
		);
	});

	it.each([
		['reduced motion', { reducedMotion: true }],
		['Save-Data', { saveData: true }],
		['missing WebGL', { webgl: false }]
	])('uses the static profile for %s', (_label, override) => {
		expect(chooseSceneQuality({ ...desktop, ...override })).toBe('static');
	});
});
