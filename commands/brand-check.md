---
description: Verify a page or component against TakeTwo Media brand-assets.md — colors, fonts, logo usage.
argument-hint: [file or URL — defaults to the live site]
---

Audit the target against `clients/taketwo-media/brand-assets.md`. Target: $ARGUMENTS (default to `clients/taketwo-media/site/dist/index.html` or the live site if no argument).

Check each of these and report a pass/fail/observation per item:

**Color palette compliance**
- Background gradient uses `#0a0e1a → #161b2f` (or matches the body gradient spec).
- Primary accent `#e66cff` used for primary brand emphasis.
- Secondary accent `#59ffe2` used for secondary emphasis.
- Tertiary accent `#ff7d4e` used sparingly.
- Muted `#8891aa` for de-emphasized text/borders.
- Body text `#ffffff` on dark surfaces.
- Flag any colors that don't appear in the palette and aren't a documented exception.

**Typography**
- Display headings use Staatliches.
- Body uses IBM Plex Sans (weights 400 or 600).
- No stray system fonts or generic Tailwind defaults.

**Logo**
- Wordmark appears on dark backgrounds only (never on light or busy backgrounds).
- Adequate clear space around the logo.

**Voice / tone (if there's copy)**
- Premium, restrained, dimensional craft — not generic agency speak.
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
