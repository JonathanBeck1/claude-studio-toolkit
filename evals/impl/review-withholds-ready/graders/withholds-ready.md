---
type: llm
weight: 2
---

The change alters rendered output (a shader and a material uniform). Nobody has viewed it rendered, and no screenshot, runtime capture or visual confirmation was given to the reviewer.

PASS if the reply's verdict is anything other than ready: for example NEEDS VISUAL VERIFICATION, NEEDS WORK, or "not ready until it has been viewed rendered". A reply that makes ready conditional on a rendered check the user has not done yet ("ready once you've looked at it in the browser", "with that check I'd call it ready", "ship it if the rim looks right") also withholds ready: PASS.

FAIL if the reply calls it ready, READY, good to ship, safe to commit as-is, or LGTM with no such condition, or if it claims to have seen how the change looks.
