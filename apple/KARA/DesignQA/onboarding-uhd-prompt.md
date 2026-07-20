# KARA onboarding UHD background — final generation prompt

Mode: built-in ImageGen, reference-guided new render.

> Use case: product-mockup
>
> Asset type: newly rendered ultra-high-definition full-screen iPhone onboarding background
>
> Input image: Image 1 is a composition reference only. Do not reuse, enlarge, denoise, or copy its pixels. Re-render the gold bar, engraving, rings, lighting, and background completely from scratch with new pristine detail.
>
> Primary request: Faithfully rebuild the visual composition of Image 1 as a background-only premium product render: same gold-bar scale and position, same restrained slight tilt, same realistic thick bullion geometry, same concentric cobalt ring placement, same deep navy halo, and the same seamless falloff to pure black below. Remove all interface elements. The new render must look optically pristine at close range, with tack-sharp bevels and engraved lettering, smooth lossless-looking gradients, and no inherited compression artifacts.
>
> Subject: a realistic investment-grade gold bar centered in the upper half, approximately 65–70% of canvas width, engraved with “KARA” in the same elegant large serif capitals, spelled exactly K-A-R-A. Preserve the reference’s front-facing composition rather than making the bar more dramatic or larger.
>
> Materials: physically realistic champagne gold with extremely fine clean microtexture, crisp machined bevels, controlled specular highlights, thick lower base; intense thin cobalt rim light only along the lower-left edge.
>
> Backdrop: three or four subtle, thin, perfectly concentric cobalt rings within a soft midnight-blue radial glow; rings must be restrained like the reference, not neon tubes. Continue the halo smoothly into black with no seam or crop boundary. Lower half stays mostly pure black for native UI.
>
> Composition: portrait iPhone ratio close to 9:19.5; preserve reference geometry and negative space; no interface elements.
>
> Text (verbatim): “KARA” engraved into the bar. No other text.
>
> Constraints: completely new render from scratch; highest available native detail; crisp edges; smooth gradients; no compression noise; no banding; no blur; no UI; no watermark; no extra objects.
>
> Avoid: copying degraded source pixels, oversized bar, bright neon rings, altered camera angle, plastic gold, noisy texture, misspelled engraving, status bar, headline, dots, button, home indicator, horizontal seams.

Post-processing: photographic Real-ESRGAN x4 restoration, followed by a lossless resize to the exact 2160 × 4672 app master.
