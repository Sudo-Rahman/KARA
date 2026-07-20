import { defineConfig, devices } from '@playwright/test';

const testEnvironment = {
	...process.env,
	PUBLIC_SITE_URL: 'http://127.0.0.1:4173',
	PUBLIC_APP_STORE_URL: 'https://apps.apple.com/app/kara/id000000000',
	PUBLIC_GOOGLE_PLAY_URL: 'https://play.google.com/store/apps/details?id=app.kara',
	PUBLIC_SUPPORT_EMAIL: 'support@kara.example',
	PUBLIC_LEGAL_NAME: 'Kara',
	METALS_DATA_MANIFEST_URL: 'http://127.0.0.1:9/v1/manifest.json'
};

export default defineConfig({
	testDir: './tests',
	fullyParallel: false,
	forbidOnly: Boolean(process.env.CI),
	retries: process.env.CI ? 2 : 0,
	reporter: 'list',
	use: {
		baseURL: 'http://127.0.0.1:4173',
		trace: 'retain-on-failure',
		screenshot: 'only-on-failure',
		video: 'retain-on-failure'
	},
	webServer: {
		command: 'pnpm dev --host 127.0.0.1 --port 4173',
		url: 'http://127.0.0.1:4173',
		reuseExistingServer: !process.env.CI,
		timeout: 120_000,
		env: testEnvironment
	},
	projects: [
		{ name: 'desktop-chromium', use: { ...devices['Desktop Chrome'] } },
		{ name: 'mobile-webkit', use: { ...devices['iPhone 13'] } }
	]
});
