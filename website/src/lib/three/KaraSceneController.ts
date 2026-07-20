import {
	ACESFilmicToneMapping,
	AdditiveBlending,
	BoxGeometry,
	BufferGeometry,
	CanvasTexture,
	Color,
	CylinderGeometry,
	DataTexture,
	DoubleSide,
	EquirectangularReflectionMapping,
	ExtrudeGeometry,
	Float32BufferAttribute,
	FogExp2,
	Group,
	HemisphereLight,
	Line,
	LineBasicMaterial,
	LineLoop,
	LinearFilter,
	Material,
	MathUtils,
	Mesh,
	MeshBasicMaterial,
	MeshPhysicalMaterial,
	OctahedronGeometry,
	PCFShadowMap,
	PerspectiveCamera,
	PlaneGeometry,
	PointLight,
	Points,
	PointsMaterial,
	Scene,
	Shape,
	SpotLight,
	SRGBColorSpace,
	Texture,
	TorusGeometry,
	Vector3,
	WebGLRenderer
} from 'three';
import { sceneQualitySettings } from './quality';
import { normalizeSceneProgress } from './timeline';
import type {
	KaraSceneController,
	KaraSceneControllerOptions,
	SceneQuality,
	SceneReadyDetail
} from './types';

type VectorTuple = readonly [number, number, number];

interface ChoreographyFrame {
	progress: number;
	position: VectorTuple;
	rotation: VectorTuple;
	scale: number;
	camera: VectorTuple;
	lookAt: VectorTuple;
}

const CHOREOGRAPHY = [
	{
		progress: 0,
		position: [1.65, 0.08, 0],
		rotation: [-0.11, -0.48, -0.04],
		scale: 0.76,
		camera: [0.25, 0.05, 7.3],
		lookAt: [0, 0, 0]
	},
	{
		progress: 0.145,
		position: [-1.05, 0.08, 0.1],
		rotation: [0.07, 0.34, -0.08],
		scale: 0.78,
		camera: [0.1, 0.12, 7.6],
		lookAt: [-0.15, 0, 0]
	},
	{
		progress: 0.285,
		position: [1.12, 0.15, 0],
		rotation: [-0.04, -0.8, 0.08],
		scale: 0.7,
		camera: [-0.15, 0.15, 7.9],
		lookAt: [0.1, 0, 0]
	},
	{
		progress: 0.43,
		position: [0, -0.08, 0.34],
		rotation: [0.13, 0.04, 0],
		scale: 0.66,
		camera: [0.3, 0.25, 7.5],
		lookAt: [0, -0.05, 0]
	},
	{
		progress: 0.575,
		position: [-1.2, -0.12, 0.18],
		rotation: [0.02, 0.48, -0.05],
		scale: 0.55,
		camera: [0.15, 0.1, 8.2],
		lookAt: [0, 0, 0]
	},
	{
		progress: 0.72,
		position: [0, 0.08, -0.08],
		rotation: [-0.04, -0.12, 0.03],
		scale: 0.64,
		camera: [0, 0, 8.6],
		lookAt: [0, 0, 0]
	},
	{
		progress: 0.86,
		position: [0, -0.04, 0.3],
		rotation: [-0.08, -0.32, -0.02],
		scale: 0.82,
		camera: [0, 0.05, 7.8],
		lookAt: [0, 0, 0]
	},
	{
		progress: 1,
		position: [0, 0.06, 0.55],
		rotation: [-0.1, 0.42, 0.025],
		scale: 1.08,
		camera: [0.1, 0.05, 7.1],
		lookAt: [0, 0, 0.1]
	}
] as const satisfies readonly ChoreographyFrame[];

const GOLD = new Color('#dcae48');
const PALE_GOLD = new Color('#ffe3a1');
const COBALT = new Color('#3263ff');
const COBALT_BRIGHT = new Color('#78a5ff');
const VOID = new Color('#08090b');

function smoothStep(start: number, end: number, value: number): number {
	const progress = MathUtils.clamp((value - start) / (end - start), 0, 1);
	return progress * progress * (3 - 2 * progress);
}

function pulse(value: number, enterStart: number, enterEnd: number, exitStart: number, exitEnd: number): number {
	return smoothStep(enterStart, enterEnd, value) * (1 - smoothStep(exitStart, exitEnd, value));
}

function interpolateTuple(from: VectorTuple, to: VectorTuple, amount: number): VectorTuple {
	return [
		MathUtils.lerp(from[0], to[0], amount),
		MathUtils.lerp(from[1], to[1], amount),
		MathUtils.lerp(from[2], to[2], amount)
	];
}

function sampleChoreography(progress: number): Omit<ChoreographyFrame, 'progress'> {
	let index = 0;
	while (index < CHOREOGRAPHY.length - 2 && progress > CHOREOGRAPHY[index + 1].progress) index += 1;

	const from = CHOREOGRAPHY[index];
	const to = CHOREOGRAPHY[index + 1];
	const localProgress = smoothStep(from.progress, to.progress, progress);

	return {
		position: interpolateTuple(from.position, to.position, localProgress),
		rotation: interpolateTuple(from.rotation, to.rotation, localProgress),
		scale: MathUtils.lerp(from.scale, to.scale, localProgress),
		camera: interpolateTuple(from.camera, to.camera, localProgress),
		lookAt: interpolateTuple(from.lookAt, to.lookAt, localProgress)
	};
}

function createRoundedRectangle(width: number, height: number, radius: number): Shape {
	const shape = new Shape();
	const left = -width / 2;
	const right = width / 2;
	const bottom = -height / 2;
	const top = height / 2;

	shape.moveTo(left + radius, bottom);
	shape.lineTo(right - radius, bottom);
	shape.quadraticCurveTo(right, bottom, right, bottom + radius);
	shape.lineTo(right, top - radius);
	shape.quadraticCurveTo(right, top, right - radius, top);
	shape.lineTo(left + radius, top);
	shape.quadraticCurveTo(left, top, left, top - radius);
	shape.lineTo(left, bottom + radius);
	shape.quadraticCurveTo(left, bottom, left + radius, bottom);

	return shape;
}

function createFallbackTexture(): DataTexture {
	const texture = new DataTexture(new Uint8Array([255, 255, 255, 0]), 1, 1);
	texture.needsUpdate = true;
	return texture;
}

function createEngravingTexture(): Texture {
	if (typeof document === 'undefined') return createFallbackTexture();

	const canvas = document.createElement('canvas');
	canvas.width = 1024;
	canvas.height = 360;
	const context = canvas.getContext('2d');
	if (!context) return createFallbackTexture();

	context.clearRect(0, 0, canvas.width, canvas.height);
	context.textAlign = 'center';
	context.textBaseline = 'middle';
	context.font = '600 190px Georgia, serif';
	context.letterSpacing = '26px';
	context.shadowColor = 'rgba(255, 229, 160, 0.24)';
	context.shadowBlur = 8;
	context.shadowOffsetY = 4;
	context.fillStyle = 'rgba(54, 30, 5, 0.88)';
	context.fillText('KARA', canvas.width / 2 + 13, canvas.height / 2 - 2);

	context.shadowColor = 'transparent';
	context.font = '500 35px "Geologica Variable", system-ui, sans-serif';
	context.letterSpacing = '8px';
	context.fillStyle = 'rgba(75, 42, 5, 0.72)';
	context.fillText('FINE GOLD  ·  999.9', canvas.width / 2 + 4, canvas.height - 50);

	const texture = new CanvasTexture(canvas);
	texture.colorSpace = SRGBColorSpace;
	texture.minFilter = LinearFilter;
	texture.generateMipmaps = true;
	return texture;
}

function createReportTexture(locale: 'fr' | 'en'): Texture {
	if (typeof document === 'undefined') return createFallbackTexture();

	const canvas = document.createElement('canvas');
	canvas.width = 768;
	canvas.height = 1024;
	const context = canvas.getContext('2d');
	if (!context) return createFallbackTexture();

	context.fillStyle = '#f2f0ea';
	context.fillRect(0, 0, canvas.width, canvas.height);
	context.fillStyle = '#111319';
	context.font = '600 42px "Geologica Variable", system-ui, sans-serif';
	context.fillText('KARA', 64, 88);
	context.font = '500 22px "Geologica Variable", system-ui, sans-serif';
	context.fillStyle = '#5f6572';
	context.fillText(locale === 'fr' ? 'Rapport patrimonial' : 'Holdings report', 64, 130);

	context.strokeStyle = '#d2d5dc';
	context.lineWidth = 2;
	context.beginPath();
	context.moveTo(64, 178);
	context.lineTo(704, 178);
	context.stroke();

	context.fillStyle = '#111319';
	context.font = '500 25px "Geologica Variable", system-ui, sans-serif';
	context.fillText(locale === 'fr' ? 'Valeur estimée' : 'Estimated value', 64, 242);
	context.font = '600 58px "Geologica Variable", system-ui, sans-serif';
	context.fillText(locale === 'fr' ? '48 620 €' : '€48,620', 64, 318);
	context.fillStyle = '#327a54';
	context.font = '500 24px "Geologica Variable", system-ui, sans-serif';
	context.fillText(locale === 'fr' ? '+ 12,4 % depuis acquisition' : '+12.4% since purchase', 64, 360);

	const bars = [0.48, 0.66, 0.57, 0.8, 0.73, 0.92, 0.86, 1];
	context.strokeStyle = '#396bff';
	context.lineWidth = 8;
	context.lineCap = 'round';
	context.beginPath();
	bars.forEach((value, index) => {
		const x = 72 + index * 88;
		const y = 604 - value * 170;
		if (index === 0) context.moveTo(x, y);
		else context.lineTo(x, y);
	});
	context.stroke();

	context.fillStyle = '#d6d9df';
	for (let index = 0; index < 5; index += 1) {
		context.fillRect(64, 690 + index * 55, 640 - index * 34, 13);
	}

	const texture = new CanvasTexture(canvas);
	texture.colorSpace = SRGBColorSpace;
	texture.minFilter = LinearFilter;
	return texture;
}

function createEnvironmentTexture(): Texture {
	if (typeof document === 'undefined') return createFallbackTexture();

	const canvas = document.createElement('canvas');
	canvas.width = 1024;
	canvas.height = 512;
	const context = canvas.getContext('2d');
	if (!context) return createFallbackTexture();

	context.fillStyle = '#07090e';
	context.fillRect(0, 0, canvas.width, canvas.height);

	const horizon = context.createLinearGradient(0, 0, canvas.width, 0);
	const stops = [
		[0, '#0b1737'],
		[0.12, '#477aff'],
		[0.19, '#11182d'],
		[0.46, '#30210e'],
		[0.57, '#fff0bf'],
		[0.64, '#9a6822'],
		[0.79, '#10172b'],
		[0.92, '#315fff'],
		[1, '#071020']
	] as const;
	for (const [offset, color] of stops) horizon.addColorStop(offset, color);
	context.globalAlpha = 0.82;
	context.fillStyle = horizon;
	context.fillRect(0, 96, canvas.width, 300);

	const zenith = context.createLinearGradient(0, 0, 0, canvas.height);
	zenith.addColorStop(0, 'rgba(99, 132, 255, 0.16)');
	zenith.addColorStop(0.48, 'rgba(255, 240, 191, 0.08)');
	zenith.addColorStop(1, 'rgba(0, 0, 0, 0.9)');
	context.globalAlpha = 1;
	context.fillStyle = zenith;
	context.fillRect(0, 0, canvas.width, canvas.height);

	const texture = new CanvasTexture(canvas);
	texture.mapping = EquirectangularReflectionMapping;
	texture.colorSpace = SRGBColorSpace;
	texture.minFilter = LinearFilter;
	return texture;
}

function seededRandom(seed: number): () => number {
	let value = seed >>> 0;
	return () => {
		value += 0x6d2b79f5;
		let result = value;
		result = Math.imul(result ^ (result >>> 15), result | 1);
		result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
		return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
	};
}

function setGroupOpacity(group: Group, opacity: number): void {
	group.visible = opacity > 0.002;
	group.traverse((object) => {
		if (!('material' in object)) return;
		const source = (object as Mesh).material;
		const materials = Array.isArray(source) ? source : [source];
		for (const material of materials) {
			material.transparent = true;
			material.opacity = opacity;
		}
	});
}

export class KaraThreeSceneController implements KaraSceneController {
	private readonly options: KaraSceneControllerOptions;
	private quality: SceneQuality;
	private container: HTMLElement | null = null;
	private scene: Scene | null = null;
	private camera: PerspectiveCamera | null = null;
	private renderer: WebGLRenderer | null = null;
	private world: Group | null = null;
	private bar: Group | null = null;
	private collectibles: Group | null = null;
	private valueOrbit: Group | null = null;
	private fragments: Group | null = null;
	private report: Group | null = null;
	private aperture: Group | null = null;
	private vault: Group | null = null;
	private dust: Points | null = null;
	private cobaltLight: PointLight | null = null;
	private goldLight: SpotLight | null = null;
	private resizeObserver: ResizeObserver | null = null;
	private intersectionObserver: IntersectionObserver | null = null;
	private animationFrame: number | null = null;
	private lastRenderTime = 0;
	private currentProgress = 0;
	private targetProgress = 0;
	private width = 1;
	private height = 1;
	private isIntersecting = true;
	private isDocumentVisible = true;
	private isMounted = false;
	private isDestroyed = false;
	private sceneBuilt = false;
	private reportedQuality: SceneQuality | null = null;
	private readonly textures = new Set<Texture>();
	private readonly lookTarget = new Vector3();

	constructor(options: KaraSceneControllerOptions = {}) {
		this.options = options;
		this.quality = options.quality ?? 'high';
	}

	mount(container: HTMLElement): boolean {
		if (this.isDestroyed || this.isMounted) return false;

		this.container = container;
		this.isMounted = true;
		this.isDocumentVisible = typeof document === 'undefined' || document.visibilityState !== 'hidden';
		this.installObservers();

		if (this.quality === 'static') {
			queueMicrotask(() => this.reportReady({ quality: 'static' }));
			return true;
		}

		const mounted = this.ensureRenderer();
		if (mounted) this.start();
		return mounted;
	}

	setProgress(progress: number): void {
		this.targetProgress = normalizeSceneProgress(progress);
		if (this.quality !== 'static') this.start();
	}

	resize(width?: number, height?: number): void {
		if (!this.container) return;

		const bounds = this.container.getBoundingClientRect();
		this.width = Math.max(1, Math.round(width ?? bounds.width ?? 1));
		this.height = Math.max(1, Math.round(height ?? bounds.height ?? 1));

		if (!this.camera || !this.renderer) return;
		this.camera.aspect = this.width / this.height;
		this.camera.updateProjectionMatrix();
		this.renderer.setSize(this.width, this.height, false);
		this.applyRendererQuality();
		this.start();
	}

	setQuality(quality: SceneQuality): void {
		if (this.isDestroyed || quality === this.quality) return;
		this.quality = quality;

		if (!this.isMounted) return;

		if (quality === 'static') {
			this.stop();
			if (this.renderer) this.renderer.domElement.style.opacity = '0';
			this.reportReady({ quality: 'static' });
			return;
		}

		if (this.ensureRenderer()) {
			this.applyRendererQuality();
			if (this.renderer) this.renderer.domElement.style.opacity = '1';
			this.resize();
			this.start();
		}
	}

	destroy(): void {
		if (this.isDestroyed) return;
		this.isDestroyed = true;
		this.stop();
		this.resizeObserver?.disconnect();
		this.intersectionObserver?.disconnect();
		this.resizeObserver = null;
		this.intersectionObserver = null;

		if (typeof document !== 'undefined') {
			document.removeEventListener('visibilitychange', this.handleVisibilityChange);
		}
		if (typeof window !== 'undefined') {
			window.removeEventListener('orientationchange', this.handleOrientationChange);
		}

		const geometries = new Set<BufferGeometry>();
		const materials = new Set<Material>();
		this.scene?.traverse((object) => {
			if ('geometry' in object && (object as Mesh).geometry) geometries.add((object as Mesh).geometry);
			if (!('material' in object)) return;
			const source = (object as Mesh).material;
			for (const material of Array.isArray(source) ? source : [source]) materials.add(material);
		});
		for (const geometry of geometries) geometry.dispose();
		for (const material of materials) material.dispose();
		for (const texture of this.textures) texture.dispose();
		this.textures.clear();

		if (this.renderer) {
			this.renderer.renderLists.dispose();
			this.renderer.dispose();
			this.renderer.forceContextLoss();
			this.renderer.domElement.remove();
		}

		this.renderer = null;
		this.scene = null;
		this.camera = null;
		this.container = null;
		this.world = null;
		this.bar = null;
		this.collectibles = null;
		this.valueOrbit = null;
		this.fragments = null;
		this.report = null;
		this.aperture = null;
		this.vault = null;
		this.dust = null;
		this.isMounted = false;
	}

	private ensureRenderer(): boolean {
		if (!this.container || this.quality === 'static') return false;
		if (this.renderer) return true;

		try {
			if (!this.sceneBuilt) this.buildScene();
			const settings = sceneQualitySettings[this.quality];
			this.renderer = new WebGLRenderer({
				alpha: true,
				antialias: settings.antialias,
				powerPreference: this.quality === 'high' ? 'high-performance' : 'default',
				premultipliedAlpha: true
			});
			this.renderer.setClearColor(VOID, 0);
			this.renderer.outputColorSpace = SRGBColorSpace;
			this.renderer.toneMapping = ACESFilmicToneMapping;
			this.renderer.toneMappingExposure = 1.12;
			this.renderer.shadowMap.type = PCFShadowMap;
			this.renderer.domElement.dataset.karaSceneCanvas = '';
			this.renderer.domElement.setAttribute('aria-hidden', 'true');
			this.renderer.domElement.setAttribute('role', 'presentation');
			this.renderer.domElement.tabIndex = -1;
			Object.assign(this.renderer.domElement.style, {
				position: 'absolute',
				inset: '0',
				width: '100%',
				height: '100%',
				display: 'block',
				opacity: '1',
				transition: 'opacity 600ms cubic-bezier(0.16, 1, 0.3, 1)'
			});
			this.container.append(this.renderer.domElement);
			this.resize();
			this.applyRendererQuality();
			return true;
		} catch (cause) {
			const error = cause instanceof Error ? cause : new Error('Unable to initialize Kara WebGL scene');
			this.quality = 'static';
			this.options.onError?.(error);
			this.reportReady({ quality: 'static' });
			return false;
		}
	}

	private buildScene(): void {
		this.scene = new Scene();
		this.scene.fog = new FogExp2(VOID, 0.055);
		const environmentTexture = createEnvironmentTexture();
		this.textures.add(environmentTexture);
		this.scene.environment = environmentTexture;
		this.scene.environmentIntensity = 0.92;
		this.camera = new PerspectiveCamera(34, 1, 0.1, 60);
		this.camera.position.set(0.25, 0.05, 7.3);

		this.world = new Group();
		this.scene.add(this.world);

		const hemisphere = new HemisphereLight('#779cff', '#08090b', 0.8);
		this.scene.add(hemisphere);

		this.cobaltLight = new PointLight(COBALT, 26, 15, 1.75);
		this.cobaltLight.position.set(-4.5, 2.7, 4.2);
		this.scene.add(this.cobaltLight);

		this.goldLight = new SpotLight(PALE_GOLD, 34, 18, Math.PI / 5.5, 0.62, 1.35);
		this.goldLight.position.set(4.2, 4.8, 6);
		this.goldLight.target.position.set(0, 0, 0);
		this.goldLight.castShadow = this.quality === 'high';
		this.goldLight.shadow.mapSize.set(1024, 1024);
		this.scene.add(this.goldLight, this.goldLight.target);

		this.vault = this.createVault();
		this.bar = this.createGoldBar();
		this.collectibles = this.createCollectibles();
		this.valueOrbit = this.createValueOrbit();
		this.fragments = this.createFragments();
		this.report = this.createReport();
		this.aperture = this.createAperture();
		this.dust = this.createDust();

		this.world.add(
			this.vault,
			this.valueOrbit,
			this.fragments,
			this.report,
			this.aperture,
			this.collectibles,
			this.bar
		);
		this.scene.add(this.dust);
		this.sceneBuilt = true;
		this.updateScene(0, 0);
	}

	private createGoldBar(): Group {
		const group = new Group();
		const shape = createRoundedRectangle(3.35, 1.72, 0.22);
		const geometry = new ExtrudeGeometry(shape, {
			depth: 0.54,
			steps: 1,
			bevelEnabled: true,
			bevelThickness: 0.13,
			bevelSize: 0.11,
			bevelOffset: -0.025,
			bevelSegments: this.quality === 'high' ? 5 : 3,
			curveSegments: this.quality === 'high' ? 8 : 5
		});
		geometry.center();

		const material = new MeshPhysicalMaterial({
			color: GOLD,
			metalness: 0.86,
			roughness: 0.23,
			clearcoat: 0.45,
			clearcoatRoughness: 0.16,
			envMapIntensity: 1.4,
			emissive: '#2b1803',
			emissiveIntensity: 0.08
		});
		const body = new Mesh(geometry, material);
		body.castShadow = true;
		body.receiveShadow = true;
		group.add(body);

		const engravingTexture = createEngravingTexture();
		this.textures.add(engravingTexture);
		const engravingMaterial = new MeshBasicMaterial({
			map: engravingTexture,
			transparent: true,
			depthWrite: false,
			polygonOffset: true,
			polygonOffsetFactor: -2
		});
		const engraving = new Mesh(new PlaneGeometry(2.62, 0.92), engravingMaterial);
		engraving.position.z = 0.415;
		group.add(engraving);

		const outlineShape = createRoundedRectangle(3.02, 1.39, 0.18);
		const outlineGeometry = new BufferGeometry().setFromPoints(outlineShape.getPoints(72));
		const outline = new LineLoop(
			outlineGeometry,
			new LineBasicMaterial({ color: '#6b3e08', transparent: true, opacity: 0.48 })
		);
		outline.position.z = 0.424;
		group.add(outline);

		return group;
	}

	private createCollectibles(): Group {
		const group = new Group();
		const material = new MeshPhysicalMaterial({
			color: '#d7a63a',
			metalness: 0.94,
			roughness: 0.25,
			clearcoat: 0.22,
			transparent: true
		});
		const edgeMaterial = new MeshBasicMaterial({ color: '#ffe3a0', transparent: true });
		const homes: VectorTuple[] = [
			[-2.45, 1.25, -0.1],
			[-2.15, -1.38, 0.15],
			[2.4, 1.22, 0.22],
			[2.55, -1.15, -0.08],
			[0.15, 1.82, -0.3]
		];

		homes.forEach((home, index) => {
			const coin = new Group();
			const radius = index === 4 ? 0.41 : 0.31 + (index % 2) * 0.07;
			const body = new Mesh(new CylinderGeometry(radius, radius, 0.105, 48), material);
			body.rotation.x = Math.PI / 2;
			body.castShadow = true;
			const edge = new Mesh(new TorusGeometry(radius * 0.73, 0.018, 8, 40), edgeMaterial);
			edge.position.z = 0.063;
			coin.add(body, edge);
			coin.userData.home = home;
			coin.userData.delay = index * 0.025;
			coin.rotation.z = index * 0.58;
			group.add(coin);
		});

		const ring = new Mesh(new TorusGeometry(0.52, 0.115, 18, 64), material);
		ring.userData.home = [1.58, -1.68, 0.25] satisfies VectorTuple;
		ring.userData.delay = 0.1;
		ring.rotation.set(0.55, 0.22, -0.4);
		ring.castShadow = true;
		group.add(ring);

		return group;
	}

	private createValueOrbit(): Group {
		const group = new Group();
		for (let ringIndex = 0; ringIndex < 4; ringIndex += 1) {
			const points: number[] = [];
			const radiusX = 2.15 + ringIndex * 0.42;
			const radiusY = 1.24 + ringIndex * 0.25;
			for (let index = 0; index <= 96; index += 1) {
				const angle = (index / 96) * Math.PI * 2;
				points.push(Math.cos(angle) * radiusX, Math.sin(angle) * radiusY, -0.5 - ringIndex * 0.16);
			}
			const geometry = new BufferGeometry();
			geometry.setAttribute('position', new Float32BufferAttribute(points, 3));
			const material = new LineBasicMaterial({
				color: ringIndex === 0 ? COBALT_BRIGHT : COBALT,
				transparent: true,
				opacity: 0,
				blending: AdditiveBlending,
				depthWrite: false
			});
			const line = new Line(geometry, material);
			line.rotation.x = (ringIndex - 1.5) * 0.08;
			line.rotation.y = (ringIndex - 1.5) * 0.13;
			group.add(line);
		}
		return group;
	}

	private createFragments(): Group {
		const group = new Group();
		const random = seededRandom(714);
		const geometry = new OctahedronGeometry(0.12, 0);
		const material = new MeshPhysicalMaterial({
			color: GOLD,
			metalness: 0.92,
			roughness: 0.28,
			transparent: true
		});

		for (let index = 0; index < 28; index += 1) {
			const fragment = new Mesh(geometry, material);
			const angle = random() * Math.PI * 2;
			const radius = 1.25 + random() * 2.25;
			fragment.userData.scatter = [
				Math.cos(angle) * radius,
				Math.sin(angle) * radius * 0.62,
				(random() - 0.5) * 1.5
			] satisfies VectorTuple;
			fragment.userData.spin = [random() * 4, random() * 4, random() * 4] satisfies VectorTuple;
			fragment.scale.setScalar(0.55 + random() * 1.2);
			group.add(fragment);
		}
		return group;
	}

	private createReport(): Group {
		const group = new Group();
		const texture = createReportTexture(this.options.locale ?? 'fr');
		this.textures.add(texture);
		const paper = new Mesh(
			new PlaneGeometry(2.8, 3.74),
			new MeshBasicMaterial({ map: texture, transparent: true, opacity: 0, side: DoubleSide })
		);
		paper.position.set(1.25, 0, -0.22);
		paper.rotation.set(-0.025, -0.19, 0.035);
		group.add(paper);
		return group;
	}

	private createVault(): Group {
		const group = new Group();
		group.position.z = -2.4;
		for (let index = 0; index < 4; index += 1) {
			const material = new MeshPhysicalMaterial({
				color: index === 0 ? '#1b2233' : '#10141e',
				metalness: 0.82,
				roughness: 0.38,
				emissive: index === 1 ? COBALT : new Color('#000000'),
				emissiveIntensity: index === 1 ? 0.34 : 0,
				transparent: true,
				opacity: 0.24 - index * 0.025
			});
			const ring = new Mesh(new TorusGeometry(3.2 + index * 0.58, 0.045 + index * 0.035, 12, 128), material);
			ring.rotation.z = index * 0.16;
			group.add(ring);
		}

		const boltGeometry = new BoxGeometry(0.11, 0.42, 0.11);
		const boltMaterial = new MeshBasicMaterial({ color: COBALT_BRIGHT, transparent: true, opacity: 0.14 });
		for (let index = 0; index < 24; index += 1) {
			const angle = (index / 24) * Math.PI * 2;
			const bolt = new Mesh(boltGeometry, boltMaterial);
			bolt.position.set(Math.cos(angle) * 3.75, Math.sin(angle) * 3.75, 0.05);
			bolt.rotation.z = angle;
			group.add(bolt);
		}
		return group;
	}

	private createAperture(): Group {
		const group = new Group();
		group.position.z = -0.85;
		const material = new MeshPhysicalMaterial({
			color: '#111722',
			metalness: 0.86,
			roughness: 0.34,
			emissive: '#10215f',
			emissiveIntensity: 0.2,
			transparent: true,
			opacity: 0
		});
		for (let index = 0; index < 12; index += 1) {
			const pivot = new Group();
			pivot.rotation.z = (index / 12) * Math.PI * 2;
			const blade = new Mesh(new BoxGeometry(1.48, 4.8, 0.12), material);
			blade.position.y = 4.15;
			blade.rotation.z = 0.24;
			pivot.userData.blade = blade;
			pivot.add(blade);
			group.add(pivot);
		}
		return group;
	}

	private createDust(): Points {
		const random = seededRandom(1988);
		const amount = this.quality === 'high' ? 440 : 220;
		const positions = new Float32Array(amount * 3);
		for (let index = 0; index < amount; index += 1) {
			positions[index * 3] = (random() - 0.5) * 16;
			positions[index * 3 + 1] = (random() - 0.5) * 10;
			positions[index * 3 + 2] = -1 - random() * 9;
		}
		const geometry = new BufferGeometry();
		geometry.setAttribute('position', new Float32BufferAttribute(positions, 3));
		const material = new PointsMaterial({
			color: COBALT_BRIGHT,
			size: this.quality === 'high' ? 0.018 : 0.024,
			transparent: true,
			opacity: 0.42,
			depthWrite: false,
			blending: AdditiveBlending
		});
		return new Points(geometry, material);
	}

	private applyRendererQuality(): void {
		if (!this.renderer || this.quality === 'static') return;
		const settings = sceneQualitySettings[this.quality];
		this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, settings.maxDpr));
		this.renderer.shadowMap.enabled = settings.shadows;
		if (this.goldLight) this.goldLight.castShadow = settings.shadows;
	}

	private updateScene(progress: number, elapsed: number): void {
		if (
			!this.world ||
			!this.bar ||
			!this.collectibles ||
			!this.valueOrbit ||
			!this.fragments ||
			!this.report ||
			!this.aperture ||
			!this.vault ||
			!this.camera
		) {
			return;
		}

		const frame = sampleChoreography(progress);
		const portrait = this.height > this.width * 1.08;
		const compact = this.width < 768;
		const mobileLandscape = this.width < 1024 && this.height < 560;
		const xCompression = portrait ? 0.46 : compact ? 0.68 : 1;
		const verticalOffset = portrait ? -1.52 : mobileLandscape ? -0.12 : 0;
		const viewportScale = portrait ? 0.6 : compact ? 0.86 : mobileLandscape ? 0.82 : 1;
		const cameraDistance = portrait ? 2.2 : compact ? 1.1 : mobileLandscape ? 1.45 : 0;

		this.bar.position.set(
			frame.position[0] * xCompression,
			frame.position[1] + verticalOffset,
			frame.position[2]
		);
		this.bar.rotation.set(
			frame.rotation[0] + Math.sin(elapsed * 0.42) * 0.018,
			frame.rotation[1] + elapsed * 0.025,
			frame.rotation[2]
		);
		const finalLift = smoothStep(0.86, 1, progress);
		this.bar.scale.setScalar(frame.scale * viewportScale * (1 + finalLift * 0.06));

		this.camera.position.set(
			frame.camera[0] * xCompression,
			frame.camera[1] + (portrait ? -0.12 : 0),
			frame.camera[2] + cameraDistance
		);
		this.lookTarget.set(frame.lookAt[0] * xCompression, frame.lookAt[1] + verticalOffset * 0.25, frame.lookAt[2]);
		this.camera.lookAt(this.lookTarget);

		const inventory = pulse(progress, 0.105, 0.205, 0.39, 0.49);
		this.collectibles.visible = inventory > 0.002;
		this.collectibles.children.forEach((child, index) => {
			const home = child.userData.home as VectorTuple;
			const delay = child.userData.delay as number;
			const arrival = smoothStep(0.1 + delay, 0.22 + delay, progress) * (1 - smoothStep(0.4, 0.49, progress));
			child.position.set(home[0] * arrival * xCompression, (home[1] + verticalOffset) * arrival, home[2] * arrival);
			child.scale.setScalar(Math.max(0.001, arrival * viewportScale));
			child.rotation.z += 0.0025 + index * 0.00025;
		});
		setGroupOpacity(this.collectibles, inventory);

		const orbitOpacity = pulse(progress, 0.235, 0.32, 0.48, 0.565);
		this.valueOrbit.scale.set(viewportScale * (portrait ? 0.74 : 1), viewportScale, viewportScale);
		this.valueOrbit.position.y = verticalOffset;
		this.valueOrbit.rotation.z = elapsed * 0.025 + progress * 0.5;
		setGroupOpacity(this.valueOrbit, orbitOpacity * 0.72);

		const fragmentAmount = pulse(progress, 0.405, 0.47, 0.59, 0.665);
		this.fragments.visible = fragmentAmount > 0.002;
		this.fragments.children.forEach((child) => {
			const scatter = child.userData.scatter as VectorTuple;
			const spin = child.userData.spin as VectorTuple;
			child.position.set(
				scatter[0] * fragmentAmount * xCompression,
				scatter[1] * fragmentAmount + verticalOffset,
				scatter[2] * fragmentAmount
			);
			child.rotation.set(spin[0] * progress + elapsed * 0.2, spin[1] * progress, spin[2] * progress);
		});
		setGroupOpacity(this.fragments, fragmentAmount);

		const reportOpacity = pulse(progress, 0.53, 0.61, 0.705, 0.77);
		this.report.position.set(portrait ? -0.42 : 0.7, verticalOffset * 0.35, 0);
		this.report.scale.setScalar(viewportScale * (portrait ? 0.76 : 0.9));
		this.report.rotation.y = MathUtils.lerp(-0.25, 0, reportOpacity);
		setGroupOpacity(this.report, reportOpacity);

		const privacyIn = smoothStep(0.685, 0.775, progress);
		const privacyOut = smoothStep(0.855, 0.965, progress);
		const privacy = privacyIn * (1 - privacyOut);
		this.aperture.visible = privacy > 0.002;
		this.aperture.rotation.z = -progress * 0.75;
		this.aperture.scale.setScalar(viewportScale * (portrait ? 0.8 : 1));
		this.aperture.position.y = verticalOffset * 0.32;
		this.aperture.children.forEach((pivot) => {
			const blade = pivot.userData.blade as Mesh;
			blade.position.y = MathUtils.lerp(4.15, 1.76, privacy);
			blade.rotation.z = MathUtils.lerp(0.24, 0.55, privacy);
		});
		setGroupOpacity(this.aperture, privacy * 0.94);

		this.vault.rotation.z = elapsed * -0.016 + progress * 0.38;
		this.vault.scale.setScalar(viewportScale * (portrait ? 0.86 : 1));
		this.vault.position.y = verticalOffset * 0.18;

		if (this.dust) {
			this.dust.rotation.y = elapsed * 0.006;
			this.dust.rotation.z = elapsed * -0.002;
		}
		if (this.cobaltLight) {
			this.cobaltLight.position.x = Math.sin(progress * Math.PI * 2.2) * 4.3;
			this.cobaltLight.position.y = 2.2 + Math.cos(elapsed * 0.35) * 0.5;
			this.cobaltLight.intensity = 21 + orbitOpacity * 14 + privacy * 7;
		}
		if (this.goldLight) {
			this.goldLight.position.x = 3.8 - progress * 2.4;
			this.goldLight.intensity = 28 + finalLift * 14;
		}
	}

	private installObservers(): void {
		if (!this.container || typeof window === 'undefined') return;

		if ('ResizeObserver' in window) {
			this.resizeObserver = new ResizeObserver((entries) => {
				const entry = entries[0];
				if (entry) this.resize(entry.contentRect.width, entry.contentRect.height);
			});
			this.resizeObserver.observe(this.container);
		}

		if ('IntersectionObserver' in window) {
			this.intersectionObserver = new IntersectionObserver(
				(entries) => {
					const entry = entries[0];
					this.isIntersecting = entry?.isIntersecting ?? true;
					if (this.isIntersecting) this.start();
					else this.stop();
				},
				{ rootMargin: '160px 0px', threshold: 0 }
			);
			this.intersectionObserver.observe(this.container.closest('main') ?? this.container);
		}

		document.addEventListener('visibilitychange', this.handleVisibilityChange);
		window.addEventListener('orientationchange', this.handleOrientationChange, { passive: true });
	}

	private readonly handleVisibilityChange = (): void => {
		this.isDocumentVisible = document.visibilityState !== 'hidden';
		if (this.isDocumentVisible) this.start();
		else this.stop();
	};

	private readonly handleOrientationChange = (): void => {
		this.resize();
	};

	private start(): void {
		if (
			this.animationFrame !== null ||
			this.isDestroyed ||
			!this.renderer ||
			this.quality === 'static' ||
			!this.isIntersecting ||
			!this.isDocumentVisible
		) {
			return;
		}
		this.animationFrame = requestAnimationFrame(this.renderFrame);
	}

	private stop(): void {
		if (this.animationFrame !== null) cancelAnimationFrame(this.animationFrame);
		this.animationFrame = null;
	}

	private readonly renderFrame = (timestamp: number): void => {
		this.animationFrame = null;
		if (
			this.isDestroyed ||
			!this.renderer ||
			!this.scene ||
			!this.camera ||
			this.quality === 'static' ||
			!this.isIntersecting ||
			!this.isDocumentVisible
		) {
			return;
		}

		const settings = sceneQualitySettings[this.quality];
		const minimumFrameDuration = 1000 / settings.targetFps;
		if (this.lastRenderTime && timestamp - this.lastRenderTime < minimumFrameDuration * 0.82) {
			this.animationFrame = requestAnimationFrame(this.renderFrame);
			return;
		}

		const deltaSeconds = this.lastRenderTime
			? Math.min((timestamp - this.lastRenderTime) / 1000, 0.08)
			: 1 / settings.targetFps;
		this.lastRenderTime = timestamp;
		const damping = 1 - Math.exp(-deltaSeconds * 12);
		this.currentProgress = MathUtils.lerp(this.currentProgress, this.targetProgress, damping);
		if (Math.abs(this.currentProgress - this.targetProgress) < 0.0001) this.currentProgress = this.targetProgress;

		this.updateScene(this.currentProgress, timestamp / 1000);
		this.renderer.render(this.scene, this.camera);
		this.reportReady({ quality: this.quality });
		if (Math.abs(this.currentProgress - this.targetProgress) >= 0.0001) {
			this.animationFrame = requestAnimationFrame(this.renderFrame);
		}
	};

	private reportReady(detail: SceneReadyDetail): void {
		if (this.reportedQuality === detail.quality) return;
		this.reportedQuality = detail.quality;
		this.options.onReady?.(detail);
	}
}

export function createKaraSceneController(
	options: KaraSceneControllerOptions = {}
): KaraSceneController {
	return new KaraThreeSceneController(options);
}
