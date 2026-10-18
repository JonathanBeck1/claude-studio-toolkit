---
type: regex
target:
  source: file
  path: src/layouts/Layout.astro
---

^(?![\s\S]*ViewTransitions)[\s\S]*<canvas[^>]*transition:persist
