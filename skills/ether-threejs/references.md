# References — Premium WebGL studios, annotated

Studio-by-studio reference list for premium WebGL work. Each entry maps a studio to ONE specific observable technique, the technique recipe file that addresses it, and a concrete copy/skip note. Open the URL before reading the entry — annotations were written from captures made 2026-04-28, not from generic agency knowledge, and sites change: re-verify before citing.

When the capture was unreliable (entry gate, GDPR overlay, wrong site, dead domain), the entry says so. Do not pretend an unreliable capture is ground truth.

Every technique file in `techniques/` is referenced by at least one studio entry below, so you can enter the skill from either direction (studio → technique, or technique → studio that proves it works).

---

### Lusion
- **URL:** https://lusion.co
- **Specific technique demonstrated:** A dense field of identical short-cylinder primitives in two colorways (cobalt blue + matte white + black) tumbling under what reads as soft physics, lit so the matte surfaces catch a single key light and the blacks fall to true black. The composition is a packed cluster — not floating particles — which is the harder problem because intersections must look intentional.
- **Where to look:** Homepage hero, immediately above the fold. The "SCROLL TO EXPLORE" prompt sits below the cluster.
- **Related technique file:** `techniques/fresnel-iridescence.md`
- **What to copy:** The two-tone-plus-black palette discipline — three values total, no gradient mush. The cluster reads as premium because the material response is uniform across all instances; nothing is "decorated" with extra shader noise.
- **What to skip:** Don't copy the literal cylinder-cluster motif — it is now strongly associated with Lusion specifically and reads as homage. Borrow the material restraint, invent your own primitive.

---

### Active Theory
- **URL:** https://activetheory.net
- **Specific technique demonstrated:** A holographic / chrome logo mark sitting in deep black space with a sparse warm-yellow particle burst trailing downward beneath it, and a faint vertical light streak rising on the left. The logo has visible refraction/double-edge ringing, suggesting a thin-film or fresnel-driven shader on a beveled extrusion rather than a flat SVG.
- **Where to look:** Homepage landing, the hero logo treatment. The particles are subtle — full-bleed black background is required to see them.
- **Related technique file:** `techniques/curl-noise-particles.md`
- **What to copy:** The particle count is tiny (looks like a few hundred max) and they're concentrated in a single arc, not scattered across the viewport. Sparse + directional reads as designed; dense + uniform reads as a screensaver.
- **What to skip:** Their particles are warm against cool — don't blindly invert this on a light background, the contrast collapses and the effect becomes invisible.

---

### Resn
- **URL:** https://resn.co.nz
- **Specific technique demonstrated:** A single dark refractive/shattered-glass form floating center-frame against near-black, with the studio name and "Est. 2004" centered through the form so the reader sees the type slightly distorted by the geometry in front of it. The shards are large and few — maybe a dozen — not a particle cloud.
- **Where to look:** Homepage hero, vertically centered. The form rotates slowly; refraction shifts as it turns.
- **Related technique file:** `techniques/raymarched-sdf-hero.md`
- **What to copy:** Type behind a refractive object is a strong premium signal because it forces real depth — you can't fake it with a CSS filter. One hero object, one piece of type, nothing else competing.
- **What to skip:** Don't try this on a light background. Refraction reads as smudges on white; it needs a near-black field for the highlights to register.

---

### Zajno
- **URL:** https://zajno.com
- **Specific technique demonstrated:** Massive custom display wordmark ("zajno®") set at hero scale — type is the hero, not a 3D object. Below it, a high-contrast product photograph (camera lens module, three circular elements) is composed as if it were a render but is actually a photo. The page treats type and image as equal-weight composition, with the wordmark approximately 60% of viewport height.
- **Where to look:** Homepage, top fold. The wordmark is the entire visual anchor.
- **Related technique file:** `techniques/msdf-typography.md`
- **What to copy:** Wordmark-as-hero is a legitimate alternative to 3D-object-as-hero. If you have a strong custom face, use it at scale before reaching for WebGL. MSDF lets you hold sharp edges at this size without raster artifacts.
- **What to skip:** They use a registered-trademark glyph (®) and a stylized "j" — don't copy the glyph treatment, copy the scale-and-weight composition strategy.

---

### EXP (exp.is)
- **URL:** https://exp.is
- **Capture caveat:** GDPR cookie banner covers the bottom 20% of the capture. Visible content above the banner is still readable.
- **Specific technique demonstrated:** Extreme typographic restraint — black hairline type ("EXP." then "is a Full-Cycle Experience Ecosystem") on white, with a single hairline circle outline filling roughly 70% of the viewport height behind the type. The corners use small dash registration marks (like print bleed marks) which cue "engineering / spec sheet" aesthetic without being literal.
- **Where to look:** Homepage hero, full viewport.
- **Related technique file:** `techniques/msdf-typography.md`
- **What to copy:** The dash registration marks at the four corners — a near-zero-cost detail that reads as deliberate compositional framing. Cheap, distinctive, and signals attention to layout rules.
- **What to skip:** A single circle outline as the only graphic element is on the edge of becoming dated (it was huge in 2020-22). If you borrow this, pair it with motion that earns the minimalism.

---

### Bonhomme
- **URL (intended):** https://bonhommeparis.com  *(NOT bonhomme.lol — see note)*
- **Capture note:** the original capture hit `bonhomme.lol`, a personal developer portfolio, not the Bonhomme Paris studio. Verify against bonhommeparis.com before relying on this entry.
- **Specific technique demonstrated:** *Cannot annotate without a verified capture.* Bonhomme Paris is known publicly for narrative scrollytelling case studies with persistent canvas state across route changes, but do not implement from that reputation alone — re-capture and verify before quoting specifics.
- **Where to look:** N/A until re-captured.
- **Related technique file:** `techniques/persistent-canvas-routing.md`
- **What to copy:** Defer until verified against the right site.
- **What to skip:** Do NOT cite "Bonhomme" as a reference in client-facing work until the URL confusion is resolved. Two distinct entities share the name.

---

### 14islands
- **URL:** https://14islands.com
- **Specific technique demonstrated:** Oversized sans-serif headline ("Design & Technology") set across two lines so each word touches a different edge of the viewport, with a small label cluster ("CREATIVE AGENCY / WE DESIGN AND BUILD...") right-aligned in the negative space. The ampersand is set in a lighter gray than the words it joins — color hierarchy doing what weight hierarchy usually does.
- **Where to look:** Homepage hero, the type composition under the nav.
- **Related technique file:** `techniques/scroll-camera-choreography.md`
- **What to copy:** Edge-anchored type as a viewport-aware composition. On scroll, the type position is what the camera/parallax should respect — type composition first, then 3D camera moves keyed to it, not the reverse.
- **What to skip:** Generic light-gray-background portfolios are a 2023-24 cliché. If you copy this layout, the rest of the page must earn the restraint with motion or material that adds depth.

---

### Hello Monday
- **URL:** https://hellomonday.com
- **Specific technique demonstrated:** A hand-drawn line illustration (two figures, one reading) sits centered above the word "Products" set in a slab serif — illustration plus serif as the hero, then a dark sidebar peeks in from the right edge, and three colored project tiles begin at the bottom edge. The "6 days until Monday" label in the corner is a dated-by-design micro-detail.
- **Where to look:** Homepage above the fold; the colored tiles below are the project grid entry points.
- **Related technique file:** `techniques/persistent-canvas-routing.md`
- **What to copy:** The dark sliding panel at the right edge of the hero is the navigation/menu surface — it sits over a single canvas that persists between hero and project tiles below. Persistent canvas is what lets the project tile colors stay alive on the same WebGL context as the hero.
- **What to skip:** Don't copy the illustration style — it is a strong studio signature for Hello Monday and reads as imitation. Copy the architectural choice (persistent canvas under HTML overlays), not the artwork.

---

### Akufen
- **URL:** https://akufen.ca
- **Capture caveat:** Full GDPR consent panel sits in the bottom-right quadrant. Hero type and project list are still legible.
- **Specific technique demonstrated:** Hero wordmark "AKFN" set at viewport-spanning scale with extreme letter-spacing — each letter occupies roughly a fifth of the viewport width, with negative space between them as the dominant visual element. Below, a body paragraph treats key terms ("Akufen", "projets", "services") as pill-shaped inline tags, mixing tag UI into running prose.
- **Where to look:** Homepage hero (the AKFN type) and the introductory paragraph immediately below.
- **Related technique file:** `techniques/msdf-typography.md`
- **What to copy:** The inline pill-tag treatment of key nouns inside running prose — a small interaction signal that those words are clickable filters, executed without breaking the paragraph rhythm.
- **What to skip:** Letter-spaced display type at this extreme is a strong house style for Akufen. Borrow the tag-in-prose detail; invent your own type composition.

---

### Locomotive
- **URL:** https://locomotive.ca
- **Capture caveat:** Cookie consent panel covers the bottom-right quadrant. Hero portrait and footer wordmark are still visible.
- **Specific technique demonstrated:** A pixelated/mosaic-faced portrait (model wearing dark turtleneck, face deliberately blocked into ~16x16 pixel cells) on a high-saturation cobalt-blue background, with display type ("Locomotive® Digital-first Design Agency") sitting on the same blue field at the bottom edge. The pixelation looks like a real-time post-process pass, not a baked image — the cell grid stays orthogonal to the viewport.
- **Where to look:** Homepage hero, the portrait module.
- **Related technique file:** `techniques/postprocessing-chain.md`
- **What to copy:** A single deliberate post-process effect (here: pixelation) applied to ONE element, not the whole scene. Constrains GPU cost and reads as compositional decision rather than filter abuse.
- **What to skip:** Don't ship pixelation as a stylistic default — it has a strong "anonymized / surveillance / web3" reading right now. Use it intentionally where the meaning fits, or it's just an Instagram filter.

---

### Studio Lumio
- **URL:** https://studiolumio.com
- **Capture caveat:** Capture only shows the entry gate ("Enter with sound / Enter without sound" on a black field with the wordmark split around the gate). Site content beyond the gate was not captured. Annotations below are limited to what the gate itself demonstrates; do not extrapolate to interior pages.
- **Specific technique demonstrated:** The entry gate as a composed object — wordmark "STUDIO" and "LUMIO" set on either side of a centered control panel, all on a near-black field with an acid-yellow (#D7FF3A-ish) action button. Sound-on / sound-off framing makes the audio-driven experience an explicit user choice, not a surprise autoplay.
- **Where to look:** Homepage on first load, the entry gate before any interior content.
- **Related technique file:** `techniques/postprocessing-chain.md`
- **What to copy:** The audio consent gate as a design opportunity, not an interruption. If your site has audio-reactive WebGL (which Studio Lumio's reputedly does), the gate is the user's contract and should be composed with the same care as the hero.
- **What to skip:** Cannot evaluate the interior site from this capture. Don't borrow Studio Lumio specifics for interior pages until you've re-captured past the gate.

---

### Ueno
- **URL:** https://ueno.co
- **Specific technique demonstrated:** A grid of four iPhone mockups arranged at three different angles (two upright, two tilted toward camera), each showing a different app screen, sitting on a white background under the line "Hi. We're a strategic design and innovation studio." Type is small, left-aligned, top of viewport — the phones are the hero, not the type.
- **Where to look:** Homepage hero, the phone grid below the intro line.
- **Related technique file:** `techniques/scroll-camera-choreography.md`
- **What to copy:** Three angles instead of four-square uniform — the small rotation differential per device is what sells "real objects" instead of "Figma frames." On scroll, those angles likely interpolate; the camera choreography keys to phone rotation, not phone position.
- **What to skip:** Stock device-mockup grids on white are now a strong "design agency from 2019" cue. If you borrow this composition, the angle interpolation and material response on the device chassis must be obviously real-time, or it reads as static.

---

### Antinomy Studio (DEAD DOMAIN)
- **URL (attempted):** https://antinomystudio.com — does not resolve as of capture date.
- **Capture note:** the domain returned no response at capture time (2026-04-28).
- **Specific technique demonstrated:** Unknown. Studio status unknown — could be relocated to a new domain, sunset, or temporary outage.
- **Where to look:** N/A.
- **Related technique file:** `techniques/raymarched-sdf-hero.md` *(tentative — based on prior reputation only; do not cite as evidence)*
- **What to copy:** Nothing, until a working URL is found. Listed here so a future session knows the studio was attempted and why no annotation exists.
- **What to skip:** Do not cite Antinomy in client-facing work until the studio is verified to still operate. Reputation-only references are how slop enters a deck.

---

## Technique-file coverage map

Every technique file referenced by at least one entry above:

- `techniques/curl-noise-particles.md` — Active Theory
- `techniques/fresnel-iridescence.md` — Lusion
- `techniques/postprocessing-chain.md` — Locomotive, Studio Lumio
- `techniques/msdf-typography.md` — Zajno, EXP, Akufen
- `techniques/scroll-camera-choreography.md` — 14islands, Ueno
- `techniques/persistent-canvas-routing.md` — Bonhomme (pending re-capture), Hello Monday
- `techniques/raymarched-sdf-hero.md` — Resn, Antinomy (pending domain recovery)

If you add a new studio entry, update this map. If a technique file has no entry, the technique recipe is unmoored — either find a studio that demonstrates it, or rewrite the recipe.
