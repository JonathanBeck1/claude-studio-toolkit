---
description: Verify a page or component against the repo's brand reference document — colors, fonts, logo usage, voice.
argument-hint: "[file or URL — defaults to the built site] [path to the brand doc]"
---

Audit the target against the brand reference document. Resolve the brand doc in this order: the second argument if given; the path `CLAUDE.md` names as the brand reference; else `brand-assets.md` at the repo root. If none exists, stop and say so — never audit against remembered or assumed colors.

Target: the first argument (default to the built `dist/index.html`, or the live site if the repo names one).

Read the brand doc first and extract: the palette (background, primary / secondary / tertiary accents, muted, text), the type stack (display and body faces, weights), logo rules, and voice adjectives. Then check each item and report pass/fail/observation:

**Color palette compliance**
- Backgrounds match the documented ground (gradient or solid).
- Primary accent used for primary emphasis; secondary for secondary; tertiary sparingly.
- Muted for de-emphasized text and borders; body text color on documented surfaces.
- Flag any color that isn't in the palette and isn't a documented exception.

**Typography**
- Display headings use the documented display face.
- Body uses the documented body face at documented weights.
- No stray system fonts or framework defaults.

**Logo**
- Placed only on the backgrounds the doc allows (e.g. a white wordmark on dark only).
- Adequate clear space.

**Voice / tone (if there's copy)**
- Matches the documented adjectives — not generic agency speak.
- No emojis unless explicitly intentional.
- No AI-listicle phrasing ("unlock", "level up", "game-changer").

**Output format**

```
## Brand Check: <target>

### [PASS] Compliant
- ...

### [FAIL] Violations
- ...

### Observations
- ...
```

Do not modify any files. Report only.
