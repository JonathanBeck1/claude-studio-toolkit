---
type: llm
---

The change alters rendered output, and nobody has viewed it rendered.

PASS if the reply's verdict is NEEDS WORK (or another verdict that sends the change back for code fixes). Otherwise, PASS only if the reply names a concrete rendered check to do before the change is called ready: a route, page or section and the state to view it in (for example the home hero at both ends of the camera scroll), a viewport or device, a screenshot to capture, or a runtime capture to take.

FAIL if the verdict withholds ready only because the change has not been seen rendered, but the reply never says what to view or capture. A bare instruction to look at it ("check it in the browser", "look at it on screen") with no page, section or state, viewport or device, or capture named is FAIL. Also FAIL if the reply calls the change ready.
