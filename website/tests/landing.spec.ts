import AxeBuilder from '@axe-core/playwright';
import { chromium, expect, test } from '@playwright/test';

test.beforeEach(async ({ page }) => {
	await page.route('https://umami.sudo-rahman.fr/**', (route) => route.abort());
});

test('renders the complete French landing and store conversions', async ({ page }) => {
	await page.goto('/');

	await expect(page).toHaveTitle(/Kara/);
	await expect(page.getByRole('heading', { level: 1 })).toContainText('Votre patrimoine');
	await expect(page.locator('#inventory')).toBeVisible();
	await expect(page.locator('#insights')).toBeVisible();
	await expect(page.locator('#simulation')).toBeVisible();
	await expect(page.locator('#report')).toBeVisible();
	await expect(page.locator('#privacy')).toBeVisible();
	await expect(page.locator('#download')).toBeVisible();
	await expect(page.locator('[data-umami-event="download_app_store"]').first()).toHaveAttribute('href', /apps\.apple\.com/);
	await expect(page.locator('[data-umami-event="download_google_play"]').first()).toHaveAttribute('href', /play\.google\.com/);

	const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
	expect(overflow).toBeLessThanOrEqual(1);
});

test('localizes the landing and utility pages in English', async ({ page }) => {
	await page.goto('/en');
	await expect(page.getByRole('heading', { level: 1 })).toContainText('Know what you hold');
	await expect(page.locator('html')).toHaveAttribute('lang', 'en');
	await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
		'href',
		'http://127.0.0.1:4173/en'
	);
	await expect(page.locator('.store-badge[data-platform="apple"] img').first()).toHaveAttribute(
		'src',
		'/store/app-store.svg'
	);

	await page.goto('/en/privacy');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/assets remain your business/i);
	await page.getByRole('link', { name: /Passer le site en français/i }).click();
	await expect(page).toHaveURL('/privacy');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/biens restent vos affaires/i);

	await page.goto('/en/support');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/clear answer/i);
});

test('updates the sale simulation with localized monetary values', async ({ page }) => {
	await page.goto('/');
	await page.locator('#sale-share').fill('100');
	await expect(page.locator('.simulator .metric.current strong')).toHaveText('24 860 €');
	await expect(page.locator('.simulator .gain strong')).toHaveText('+3 842 €');

	await page.goto('/en');
	await page.locator('#sale-share').fill('100');
	await expect(page.locator('.simulator .metric.current strong')).toHaveText('€24,860');
	await expect(page.locator('.simulator .gain strong')).toHaveText('+€3,842');
});

test('keeps every chapter and the 3D fallback on a narrow mobile viewport', async ({ page }) => {
	await page.setViewportSize({ width: 320, height: 700 });
	await page.goto('/');

	await expect(page.locator('.kara-three-scene')).toBeAttached();
	for (const id of ['inventory', 'insights', 'simulation', 'report', 'privacy', 'download']) {
		await expect(page.locator(`#${id}`)).toBeAttached();
	}

	const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
	expect(overflow).toBeLessThanOrEqual(1);
});

test('uses the static scene for reduced motion without losing content', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	await expect(page.locator('.kara-three-scene')).toHaveAttribute('data-quality', 'static');
	await expect(page.getByRole('heading', { level: 2, name: /Chaque objet|Every object/ })).toBeVisible();
});

test('passes an automated accessibility scan on the primary page', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	const results = await new AxeBuilder({ page }).analyze();
	expect(results.violations).toEqual([]);
});

test('shows QR codes on desktop and keeps direct store links on compact screens', async ({ page }) => {
	await page.goto('/');
	await page.locator('#download').scrollIntoViewIfNeeded();

	const qrFrames = page.locator('#download .store-qr-frame');
	const storeLinks = page.locator('#download [data-umami-event]');
	await expect(storeLinks).toHaveCount(2);

	if ((page.viewportSize()?.width ?? 0) >= 1024) {
		await expect(qrFrames.first()).toBeVisible();
		await expect(page.locator('#download .store-qr img')).toHaveCount(2);
	} else {
		await expect(qrFrames.first()).toBeHidden();
	}
});

test('keeps the primary navigation keyboard-operable', async ({ page, browserName }) => {
	test.skip(browserName === 'webkit', 'macOS WebKit follows the system Full Keyboard Access setting.');
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	await page.keyboard.press('Tab');
	await expect(page.locator('.skip-link')).toBeFocused();
	await page.keyboard.press('Tab');
	await expect(page.locator('.site-header .wordmark')).toBeFocused();
	await page.keyboard.press('Shift+Tab');
	await expect(page.locator('.skip-link')).toBeFocused();
	await page.keyboard.press('Enter');
	await expect(page).toHaveURL(/#main-content$/);
});

test('falls back to the complete static experience when WebGL is unavailable', async ({ page }) => {
	await page.addInitScript(() => {
		const originalGetContext = HTMLCanvasElement.prototype.getContext;
		HTMLCanvasElement.prototype.getContext = function (
			this: HTMLCanvasElement,
			contextId: string,
			...args: unknown[]
		) {
			if (contextId === 'webgl' || contextId === 'webgl2') return null;
			return (originalGetContext as (...parameters: unknown[]) => RenderingContext | null).call(
				this,
				contextId,
				...args
			);
		} as typeof HTMLCanvasElement.prototype.getContext;
	});

	await page.goto('/');
	await expect(page.locator('.kara-three-scene')).toHaveAttribute('data-quality', 'static');
	await expect(page.locator('#download')).toBeAttached();
});

test('runs the complete WebGL choreography with desktop and mobile quality budgets', async ({
	browserName
}) => {
	test.skip(browserName !== 'chromium', 'The forced software WebGL renderer is exercised once.');

	const webglBrowser = await chromium.launch({
		args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader']
	});

	try {
		for (const setup of [
			{ viewport: { width: 1440, height: 900 }, quality: 'high' },
			{ viewport: { width: 390, height: 844 }, quality: 'mobile' }
		] as const) {
			const livePage = await webglBrowser.newPage({ viewport: setup.viewport });
			await livePage.route('https://umami.sudo-rahman.fr/**', (route) => route.abort());
			await livePage.goto('http://127.0.0.1:4173/');
			await expect(livePage.locator('.kara-three-scene')).toHaveAttribute(
				'data-quality',
				setup.quality,
				{ timeout: 20_000 }
			);
			await expect(livePage.locator('canvas[data-kara-scene-canvas]')).toBeAttached({
				timeout: 20_000
			});

			await livePage.evaluate(() => {
				document.documentElement.style.scrollBehavior = 'auto';
				window.scrollTo(0, document.documentElement.scrollHeight - window.innerHeight);
			});
			await expect
				.poll(async () => Number(await livePage.locator('.kara-three-scene').getAttribute('data-progress')))
				.toBeGreaterThan(0.9);
			await expect(livePage.locator('canvas[data-kara-scene-canvas]')).toBeAttached();
			await livePage.close();
		}
	} finally {
		await webglBrowser.close();
	}
});

test('has no horizontal overflow across the supported responsive matrix', async ({
	page,
	browserName
}) => {
	test.skip(browserName !== 'chromium', 'The explicit matrix is covered once in Chromium.');
	await page.emulateMedia({ reducedMotion: 'reduce' });

	for (const viewport of [
		{ width: 320, height: 700 },
		{ width: 375, height: 812 },
		{ width: 390, height: 844 },
		{ width: 430, height: 932 },
		{ width: 768, height: 1024 },
		{ width: 1024, height: 768 },
		{ width: 1440, height: 900 },
		{ width: 1920, height: 1080 }
	]) {
		await page.setViewportSize(viewport);
		await page.goto('/');

		const measurements = await page.evaluate(() => {
			const heading = document.querySelector('h1')?.getBoundingClientRect();
			return {
				overflow: document.documentElement.scrollWidth - window.innerWidth,
				headingLeft: heading?.left ?? -1,
				headingRight: heading?.right ?? window.innerWidth + 1
			};
		});

		expect(measurements.overflow, `${viewport.width}px overflow`).toBeLessThanOrEqual(1);
		expect(measurements.headingLeft, `${viewport.width}px heading left`).toBeGreaterThanOrEqual(0);
		expect(measurements.headingRight, `${viewport.width}px heading right`).toBeLessThanOrEqual(
			viewport.width
		);
	}
});

test('matches the deterministic static hero snapshot', async ({ page, browserName }) => {
	test.skip(browserName !== 'chromium', 'The reference snapshot is generated in Chromium.');
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');
	await page.evaluate(() => document.fonts.ready);

	await expect(page).toHaveScreenshot('kara-hero-static.png', {
		animations: 'disabled',
		fullPage: false
	});
});

test('passes accessibility scans on the editorial pages', async ({ page }) => {
	for (const path of ['/privacy', '/support']) {
		await page.goto(path);
		const results = await new AxeBuilder({ page }).analyze();
		expect(results.violations, path).toEqual([]);
	}
});
