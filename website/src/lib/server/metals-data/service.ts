import { env } from '$env/dynamic/private';

import fallbackData from './fallback/v1/metals-monthly.json?raw';
import fallbackManifest from './fallback/v1/manifest.json?raw';
import { MetalsDataCache } from './cache';

const DEFAULT_MANIFEST_URL =
	'https://raw.githubusercontent.com/Sudo-Rahman/KARA/main/website/data/v1/manifest.json';
const REFRESH_INTERVAL_MS = 12 * 60 * 60 * 1000;
const encoder = new TextEncoder();

export const metalsDataCache = new MetalsDataCache({
	fallback: {
		manifestBytes: encoder.encode(fallbackManifest),
		dataBytes: encoder.encode(fallbackData)
	},
	manifestUrl: env.METALS_DATA_MANIFEST_URL ?? DEFAULT_MANIFEST_URL
});

let refreshTimer: ReturnType<typeof setInterval> | undefined;

export function startMetalsDataRefresh(): void {
	if (refreshTimer !== undefined) return;

	void metalsDataCache.refresh();
	refreshTimer = setInterval(() => {
		void metalsDataCache.refresh();
	}, REFRESH_INTERVAL_MS);
	refreshTimer.unref?.();
}
