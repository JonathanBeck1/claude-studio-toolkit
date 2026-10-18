---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

(?:async\s+)?exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(|^(?=[\s\S]*(?:async\s+)?exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*?\bthis\.(\w+)\()[\s\S]*\n\s*(?:(?:private|protected|public|override)\s+)*\2\s*\(\)\s*(?::\s*[\w<>]+\s*)?\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(
