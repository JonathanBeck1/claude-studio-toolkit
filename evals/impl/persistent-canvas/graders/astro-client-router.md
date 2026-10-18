---
type: regex
target:
  source: file
  path: src/layouts/Layout.astro
weight: 2
---

import\s*\{[^}]*\bClientRouter\b[^}]*\}\s*from\s*['"]astro:transitions['"][\s\S]*<ClientRouter\s*/>
