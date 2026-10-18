---
type: llm
weight: 2
---

The change alters rendered output (a shader and a material uniform). Nobody has viewed it rendered, and no screenshot, runtime capture or visual confirmation was given to the reviewer.

PASS if the reply does not approve the change as ready to ship, and says it has to be viewed rendered (in a browser, a screenshot, or a named viewport) before it can be called ready. A verdict such as "needs visual verification" or "needs work" passes.

FAIL if the reply says it is ready, READY, good to ship, safe to commit as-is, or LGTM without that rendered check, or if it claims to have seen how the change looks.
