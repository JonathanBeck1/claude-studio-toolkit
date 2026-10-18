---
type: regex
target:
  source: file
  path: src/layouts/Layout.astro
---

<script\s+is:inline>[\s\S]*?scrollRestoration\s*=\s*['"]manual['"]
