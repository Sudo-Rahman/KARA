import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

function addSharedMotion(): void {
	const load = gsap.timeline({ defaults: { ease: 'power4.out' } });
	load
		.from('.hero-word > span', {
			yPercent: 108,
			duration: 0.95,
			stagger: 0.09
		})
		.from('.hero-animate', { y: 22, opacity: 0, duration: 0.72, stagger: 0.08 }, 0.22)
		.from(
			'.aperture-rotator',
			{ scale: 0.72, rotation: -18, opacity: 0, duration: 1.25 },
			0.08
		)
		.from('.hero-device', { y: 90, rotation: 5, opacity: 0, duration: 1.08 }, 0.34);

	gsap.to('.aperture-rotator', {
		rotation: 72,
		scale: 1.12,
		ease: 'none',
		scrollTrigger: {
			trigger: '.hero',
			start: 'top top',
			end: 'bottom top',
			scrub: 1
		}
	});

	gsap.to('.hero-device', {
		yPercent: 18,
		rotation: -2.5,
		ease: 'none',
		scrollTrigger: {
			trigger: '.hero',
			start: 'top top',
			end: 'bottom top',
			scrub: 1
		}
	});

	gsap.utils.toArray<HTMLElement>('[data-parallax]').forEach((element, index) => {
		gsap.to(element, {
			yPercent: index % 2 === 0 ? -14 : 12,
			xPercent: index % 2 === 0 ? -5 : 4,
			ease: 'none',
			scrollTrigger: {
				trigger: element.closest('section') ?? element,
				start: 'top bottom',
				end: 'bottom top',
				scrub: 1.2
			}
		});
	});

	gsap.fromTo(
		'.privacy-orbit',
		{ scale: 0.78, rotation: -22 },
		{
			scale: 1.05,
			rotation: 48,
			ease: 'none',
			scrollTrigger: {
				trigger: '.privacy-section',
				start: 'top bottom',
				end: 'bottom top',
				scrub: 1
			}
		}
	);

	gsap.fromTo(
		'.final-aperture',
		{ scale: 0.78, rotation: -28, opacity: 0.12 },
		{
			scale: 1.12,
			rotation: 44,
			opacity: 0.42,
			ease: 'none',
			scrollTrigger: {
				trigger: '.final-cta',
				start: 'top bottom',
				end: 'bottom top',
				scrub: 1.1
			}
		}
	);

	gsap.fromTo(
		'.final-glow',
		{ scale: 0.72, opacity: 0.18 },
		{
			scale: 1.24,
			opacity: 0.62,
			ease: 'none',
			scrollTrigger: {
				trigger: '.final-cta',
				start: 'top bottom',
				end: 'bottom top',
				scrub: 1.1
			}
		}
	);
}

function addDesktopMotion(): void {
	const manifestoMotion = gsap.timeline({
		scrollTrigger: {
			trigger: '.manifesto',
			start: 'top bottom',
			end: 'bottom top',
			scrub: 1.1
		}
	});

	manifestoMotion
		.fromTo(
			'.manifesto-vault__shell',
			{ scale: 0.96, rotation: -2.4, xPercent: 2 },
			{ scale: 1.08, rotation: 2.8, xPercent: -2, ease: 'none' },
			0
		)
		.fromTo(
			'.manifesto-vault__device',
			{ yPercent: -34, rotation: 2.5 },
			{ yPercent: -59, rotation: -2.2, ease: 'none' },
			0
		)
		.fromTo(
			'.manifesto-vault__glow',
			{ scale: 0.68, opacity: 0.28 },
			{ scale: 1.25, opacity: 0.78, ease: 'none' },
			0
		);

	gsap.to('.showcase-stage__dial', {
		rotation: 128,
		scale: 1.06,
		ease: 'none',
		scrollTrigger: {
			trigger: '.showcase',
			start: 'top bottom',
			end: 'bottom top',
			scrub: 1.2
		}
	});

	gsap.fromTo(
		'.journey-progress',
		{ scaleX: 0 },
		{
			scaleX: 1,
			ease: 'none',
			scrollTrigger: {
				trigger: '.journey',
				start: 'top 65%',
				end: 'bottom 70%',
				scrub: 0.8
			}
		}
	);

	gsap.fromTo(
		'.journey-step > span',
		{ scale: 0.35 },
		{
			scale: 1,
			stagger: 0.16,
			ease: 'power4.out',
			scrollTrigger: {
				trigger: '.journey-steps',
				start: 'top 78%',
				end: 'bottom 52%',
				scrub: 0.55
			}
		}
	);
}

function addShowcaseMotion(): void {
	gsap.utils.toArray<HTMLElement>('.showcase-step').forEach((step, index) => {
		const device = step.querySelector<HTMLElement>('.showcase-mobile-device .device');
		const orbit = step.querySelector<HTMLElement>('.showcase-mobile-device__orbit');
		const beam = step.querySelector<HTMLElement>('.showcase-mobile-device__beam');
		const copyElements = step.querySelectorAll<HTMLElement>('h3, p, small');
		const direction = index % 2 === 0 ? -1 : 1;
		if (!device || !orbit || !beam) return;

		const stepMotion = gsap.timeline({
			scrollTrigger: {
				trigger: step,
				start: 'top 88%',
				end: 'bottom 28%',
				scrub: 0.62
			}
		});

		stepMotion
			.fromTo(
				copyElements,
				{ x: direction * 18 },
				{ x: 0, stagger: 0.045, ease: 'none' },
				0
			)
			.fromTo(
				device,
				{
					xPercent: direction * 22,
					y: 76,
					scale: 0.87,
					rotation: direction * 6.5,
					rotateY: direction * 11,
					transformPerspective: 900
				},
				{
					xPercent: 0,
					y: -12,
					scale: 1,
					rotation: 0,
					rotateY: 0,
					ease: 'none'
				},
				0
			)
			.fromTo(
				orbit,
				{ rotation: direction * -74, scale: 0.72, opacity: 0.2 },
				{ rotation: direction * 96, scale: 1.07, opacity: 0.76, ease: 'none' },
				0
			)
			.fromTo(
				beam,
				{ xPercent: direction * -42, rotation: direction * -10, opacity: 0.08 },
				{ xPercent: direction * 34, rotation: direction * 12, opacity: 0.46, ease: 'none' },
				0
			);
	});
}

function addJourneyMotion(): void {
	gsap.fromTo(
		'.journey-progress',
		{ scaleY: 0 },
		{
			scaleY: 1,
			ease: 'none',
			scrollTrigger: {
				trigger: '.journey-steps',
				start: 'top 82%',
				end: 'bottom 46%',
				scrub: 0.45
			}
		}
	);

	gsap.utils.toArray<HTMLElement>('.journey-step').forEach((step, index) => {
		gsap.fromTo(
			step,
			{ x: index % 2 === 0 ? -18 : 18 },
			{
				x: 0,
				ease: 'none',
				scrollTrigger: {
					trigger: step,
					start: 'top 88%',
					end: 'center 64%',
					scrub: 0.35
				}
			}
		);

		const marker = step.querySelector<HTMLElement>(':scope > span');
		if (!marker) return;
		gsap.fromTo(
			marker,
			{ scale: 0.35 },
			{
				scale: 1,
				ease: 'power4.out',
				scrollTrigger: {
					trigger: step,
					start: 'top 86%',
					end: 'top 66%',
					scrub: 0.3
				}
			}
		);
	});
}

function addCompactMotion(root: HTMLElement): void {
	gsap.fromTo(
		'.mobile-scroll-progress span',
		{ scaleX: 0 },
		{
			scaleX: 1,
			ease: 'none',
			scrollTrigger: {
				trigger: root,
				start: 'top top',
				end: 'bottom bottom',
				scrub: 0.2
			}
		}
	);

	gsap.fromTo(
		'.hero-light',
		{ scale: 0.82, xPercent: -8, yPercent: -4, opacity: 0.62 },
		{
			scale: 1.18,
			xPercent: 8,
			yPercent: 7,
			opacity: 1,
			ease: 'none',
			scrollTrigger: {
				trigger: '.hero',
				start: 'top top',
				end: 'bottom top',
				scrub: 0.7
			}
		}
	);

	const manifestoMotion = gsap.timeline({
		scrollTrigger: {
			trigger: '.manifesto',
			start: 'top 92%',
			end: 'bottom 12%',
			scrub: 0.72
		}
	});

	manifestoMotion
		.fromTo(
			'.manifesto-vault__shell',
			{ scale: 0.97, rotation: -3.2, xPercent: -2.5 },
			{ scale: 1.09, rotation: 2.2, xPercent: 2, ease: 'none' },
			0
		)
		.fromTo(
			'.manifesto-vault__device',
			{ yPercent: -22, scale: 0.82, rotation: 4.5 },
			{ yPercent: -61, scale: 1.04, rotation: -1.4, ease: 'none' },
			0
		)
		.fromTo(
			'.manifesto-vault__glow',
			{ scale: 0.62, opacity: 0.24 },
			{ scale: 1.34, opacity: 0.82, ease: 'none' },
			0
		);

	addShowcaseMotion();
	addJourneyMotion();

	const privacyMotion = gsap.timeline({
		scrollTrigger: {
			trigger: '.privacy-section',
			start: 'top 82%',
			end: 'bottom 24%',
			scrub: 0.68
		}
	});

	privacyMotion
		.fromTo(
			'.sensitive-demo',
			{ y: 28, scale: 0.94 },
			{ y: 0, scale: 1, ease: 'none' },
			0
		)
		.fromTo(
			'.privacy-device',
			{ yPercent: 18, scale: 0.88, rotation: 5.5 },
			{ yPercent: -7, scale: 1.02, rotation: -2.4, ease: 'none' },
			0.08
		)
		.fromTo(
			'.privacy-node',
			{ scale: 0.68, xPercent: 12 },
			{ scale: 1, xPercent: 0, stagger: 0.08, ease: 'power4.out' },
			0.18
		)
		.fromTo(
			'.privacy-proofs > div > span',
			{ scale: 0.64, rotation: -16 },
			{ scale: 1, rotation: 0, stagger: 0.08, ease: 'power4.out' },
			0.08
		);

	const finalCopy = gsap.timeline({
		scrollTrigger: {
			trigger: '.final-cta',
			start: 'top 82%',
			end: 'center 52%',
			scrub: 0.55
		}
	});

	finalCopy
		.fromTo(
			'.final-cta h2',
			{ y: 48, scale: 0.94 },
			{ y: 0, scale: 1, ease: 'none' },
			0
		)
		.fromTo('.final-cta p', { y: 30 }, { y: 0, ease: 'none' }, 0.06)
		.fromTo(
			'.final-download',
			{ y: 18, scale: 0.94 },
			{ y: 0, scale: 1, ease: 'none' },
			0.12
		);
}

export function createLandingMotion(root: HTMLElement): () => void {
	gsap.registerPlugin(ScrollTrigger);
	const responsiveMotion = gsap.matchMedia(root);
	const context = gsap.context(() => {
		addSharedMotion();
		responsiveMotion.add('(min-width: 64rem)', addDesktopMotion);
		responsiveMotion.add('(max-width: 63.99rem)', () => addCompactMotion(root));
	}, root);

	ScrollTrigger.refresh();
	return () => {
		responsiveMotion.revert();
		context.revert();
	};
}
