---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

(?:async\s+)?exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(|(?:async\s+)?exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*?\bthis\.(\w+)\([\s\S]*\n\s*(?:(?:private|protected|public|override|readonly)\s+)*\2\s*(?:=\s*)?\(\)\s*(?::\s*[\w<>]+\s*)?(?:=>\s*)?\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(|\n\s*(?:(?:private|protected|public|override|readonly)\s+)*(\w+)\s*(?:=\s*)?\(\)\s*(?::\s*[\w<>]+\s*)?(?:=>\s*)?\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\([\s\S]*(?:async\s+)?exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*?\bthis\.\4\(
