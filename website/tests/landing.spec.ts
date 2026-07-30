import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

test.beforeEach(async ({ page }) => {
	await page.route('https://umami.sudo-rahman.fr/**', (route) => route.abort());
});

test('renders the complete French landing and store conversions', async ({ page }) => {
	await page.goto('/');

	await expect(page).toHaveTitle(/KARA/);
	await expect(page.getByRole('heading', { level: 1 })).toContainText('Votre patrimoine');
	await expect(page.locator('#manifeste')).toBeVisible();
	await expect(page.locator('#experience')).toBeVisible();
	await expect(page.locator('#confidentialite')).toBeVisible();
	await expect(page.locator('#download')).toBeVisible();
	await expect(page.locator('a[href*="apps.apple.com"]')).toHaveCount(3);
	await expect(page.locator('.manifesto-vault__shell')).toHaveAttribute(
		'src',
		'/landing/materials/manifesto-vault-v2.webp'
	);
	await expect(page.locator('.manifesto-vault__device img')).toHaveAttribute(
		'src',
		'/landing/screens/fr/03-detail-actif.webp'
	);

	const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
	expect(overflow).toBeLessThanOrEqual(1);
});

test('localizes the landing and utility pages in English', async ({ page }) => {
	await page.goto('/en');
	await expect(page.getByRole('heading', { level: 1 })).toContainText('Your holdings');
	await expect(page.locator('html')).toHaveAttribute('lang', 'en');
	await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
		'href',
		'http://127.0.0.1:4173/en'
	);
	await expect(page.locator('.hero-device img')).toHaveAttribute(
		'src',
		'/landing/screens/en/01-vault.webp'
	);

	await page.goto('/en/privacy');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/assets remain your business/i);
	await page.getByRole('link', { name: /Show the site in French/i }).click();
	await expect(page).toHaveURL('/privacy');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/biens restent vos affaires/i);

	await page.goto('/en/support');
	await expect(page.getByRole('heading', { level: 1 })).toContainText(/clear answer/i);
});

test('reveals and hides the illustrative portfolio value', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');
	const value = page.locator('.sensitive-demo strong');
	const toggle = page.locator('.sensitive-demo button');

	await expect(value).toHaveText('••••• €');
	await expect
		.poll(async () => {
			if ((await toggle.getAttribute('aria-pressed')) === 'false') await toggle.click();
			return toggle.getAttribute('aria-pressed');
		})
		.toBe('true');
	await expect(value).toHaveText('17 569 €');
	await expect(page.getByRole('button', { name: 'Masquer les montants' })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
});

test('keeps every chapter on a narrow mobile viewport', async ({ page }) => {
	await page.setViewportSize({ width: 320, height: 700 });
	await page.goto('/');

	for (const id of ['manifeste', 'experience', 'confidentialite', 'download']) {
		await expect(page.locator(`#${id}`)).toBeAttached();
	}
	await expect(page.locator('.manifesto-vault__shell')).toBeAttached();
	await expect(page.locator('.showcase-mobile-device')).toHaveCount(4);

	const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
	expect(overflow).toBeLessThanOrEqual(1);
});

test('keeps the vault phone and circular privacy control optically centred on mobile', async ({
	page,
	browserName
}) => {
	test.skip(browserName !== 'chromium', 'The geometry assertion is covered once in Chromium.');
	await page.setViewportSize({ width: 390, height: 844 });
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	const geometry = await page.evaluate(() => {
		const shell = document.querySelector<HTMLElement>('.manifesto-vault__shell');
		const device = document.querySelector<HTMLElement>('.manifesto-vault__device');
		const deviceShell = document.querySelector<HTMLElement>(
			'.manifesto-vault__device .device__shell'
		);
		const heroAperture = document.querySelector<HTMLElement>('.aperture-rotator');
		const heroDevice = document.querySelector<HTMLElement>('.hero-device');
		const button = document.querySelector<HTMLButtonElement>('.sensitive-demo button');
		const icon = button?.querySelector<SVGElement>('svg');
		if (!shell || !device || !deviceShell || !heroAperture || !heroDevice || !button || !icon) {
			throw new Error('Missing geometry target');
		}

		const shellBox = shell.getBoundingClientRect();
		const deviceBox = device.getBoundingClientRect();
		const heroApertureBox = heroAperture.getBoundingClientRect();
		const heroDeviceBox = heroDevice.getBoundingClientRect();
		const buttonBox = button.getBoundingClientRect();
		const iconBox = icon.getBoundingClientRect();
		const horizontalRadius = Number.parseFloat(getComputedStyle(deviceShell).borderTopLeftRadius);

		return {
			heroDeltaX:
				heroDeviceBox.left +
				heroDeviceBox.width / 2 -
				(heroApertureBox.left + heroApertureBox.width / 2),
			vaultDeltaX: deviceBox.left + deviceBox.width / 2 - (shellBox.left + shellBox.width * 0.587),
			vaultDeltaY: deviceBox.top + deviceBox.height / 2 - (shellBox.top + shellBox.height * 0.469),
			iconDeltaX: iconBox.left + iconBox.width / 2 - (buttonBox.left + buttonBox.width / 2),
			iconDeltaY: iconBox.top + iconBox.height / 2 - (buttonBox.top + buttonBox.height / 2),
			deviceRadiusRatio: horizontalRadius / deviceBox.width
		};
	});

	expect(Math.abs(geometry.heroDeltaX)).toBeLessThanOrEqual(0.5);
	expect(Math.abs(geometry.vaultDeltaX)).toBeLessThanOrEqual(0.5);
	expect(Math.abs(geometry.vaultDeltaY)).toBeLessThanOrEqual(0.5);
	expect(Math.abs(geometry.iconDeltaX)).toBeLessThanOrEqual(0.75);
	expect(Math.abs(geometry.iconDeltaY)).toBeLessThanOrEqual(0.75);
	expect(geometry.deviceRadiusRatio).toBeLessThan(0.16);
});

test('runs a dedicated scroll choreography on compact viewports', async ({ page, browserName }) => {
	test.skip(browserName !== 'chromium', 'The motion assertion is covered once in Chromium.');
	await page.setViewportSize({ width: 390, height: 844 });
	await page.goto('/');
	await page.waitForTimeout(700);

	const firstDevice = page.locator('.showcase-mobile-device .device').first();
	const initialTransform = await firstDevice.evaluate((element) => getComputedStyle(element).transform);
	const manifestoDevice = page.locator('.manifesto-vault__device');
	await expect.poll(() => manifestoDevice.evaluate((element) => element.style.transform)).not.toBe('');

	const manifestoPhoneClearance = await page.evaluate(() => {
		const section = document.querySelector<HTMLElement>('.manifesto');
		const device = document.querySelector<HTMLElement>('.manifesto-vault__device');
		if (!section || !device) throw new Error('Missing manifesto containment target');

		return section.getBoundingClientRect().bottom - device.getBoundingClientRect().bottom;
	});
	expect(manifestoPhoneClearance).toBeGreaterThanOrEqual(24);

	await page.locator('.showcase-step').first().scrollIntoViewIfNeeded();
	await page.evaluate(() => window.scrollBy({ top: 420, behavior: 'instant' }));

	await expect
		.poll(() => firstDevice.evaluate((element) => getComputedStyle(element).transform))
		.not.toBe(initialTransform);

	const progressScale = await page.locator('.mobile-scroll-progress span').evaluate((element) => {
		return new DOMMatrixReadOnly(getComputedStyle(element).transform).a;
	});
	expect(progressScale).toBeGreaterThan(0.15);
});

test('preserves the complete experience when reduced motion is requested', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
	await expect(
		page.getByRole('heading', { level: 2, name: /Un coffre numérique|A digital vault/ })
	).toBeVisible();
	await expect(page.locator('.manifesto-vault__shell')).toBeVisible();
	await expect(page.locator('.mobile-scroll-progress')).toBeHidden();
	expect(await page.evaluate(() => window.matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(
		true
	);
});

test('reacts when the motion preference changes while the page is open', async ({
	page,
	browserName
}) => {
	test.skip(browserName !== 'chromium', 'The live preference assertion is covered once in Chromium.');
	await page.setViewportSize({ width: 390, height: 844 });
	await page.goto('/');

	const device = page.locator('.showcase-mobile-device .device').first();
	await expect.poll(() => device.evaluate((element) => element.style.transform)).not.toBe('');

	await page.emulateMedia({ reducedMotion: 'reduce' });
	await expect.poll(() => device.evaluate((element) => element.style.transform)).toBe('');
	await expect(page.locator('.mobile-scroll-progress')).toBeHidden();

	await page.emulateMedia({ reducedMotion: 'no-preference' });
	await expect.poll(() => device.evaluate((element) => element.style.transform)).not.toBe('');
});

test('passes an automated accessibility scan on the primary page', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	const results = await new AxeBuilder({ page }).analyze();
	expect(results.violations).toEqual([]);
});

test('switches the sticky showcase screen through accessible controls', async ({
	page,
	browserName
}) => {
	test.skip(browserName === 'webkit', 'Compact layouts present each screen inline.');
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');
	await page.locator('#experience').scrollIntoViewIfNeeded();

	const controls = page.locator('.showcase-dots button');
	await expect(controls).toHaveCount(4);
	await controls.nth(1).click();
	await expect(controls.nth(1)).toHaveAttribute('aria-pressed', 'true');
	await expect(page.locator('.showcase-screen.active img')).toHaveAttribute(
		'src',
		'/landing/screens/fr/04-performance.webp'
	);
});

test('keeps the primary navigation keyboard-operable', async ({ page, browserName }) => {
	test.skip(browserName === 'webkit', 'macOS WebKit follows the system Full Keyboard Access setting.');
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');

	await page.keyboard.press('Tab');
	await expect(page.locator('.skip-link')).toBeFocused();
	await page.keyboard.press('Tab');
	await expect(page.locator('.site-header .brand-link')).toBeFocused();
	await page.keyboard.press('Shift+Tab');
	await expect(page.locator('.skip-link')).toBeFocused();
	await page.keyboard.press('Enter');
	await expect(page).toHaveURL(/#main-content$/);
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
