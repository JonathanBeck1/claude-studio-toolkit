---
type: regex
target:
  source: file
  path: src/layouts/Layout.astro
---

<script(?![^>]*is:inline)[^>]*>[\s\S]*?scene/boot
