---
description: End-of-build flow for deliverable changes — premium-review, commit, push.
argument-hint: [optional commit message, otherwise drafted from the diff]
---

Run the canonical ship flow. Commit message hint: $ARGUMENTS (otherwise draft one from the diff).

Steps in order — do not skip:

1. **Snapshot state.** Run `git status` and `git diff --stat`. Confirm there are changes to ship. If working tree is clean, abort with "Nothing to ship."

2. **Run premium-review.** Invoke the `premium-review` subagent (`claude-studio-toolkit:premium-review` when installed as a plugin) against the current diff. It chains threejs-audit + brand-check + the ship checklist. Wait for its punch list. Include in the subagent prompt, verbatim, any evidence from this session: `/threejs-audit` Evidence blocks, `getDiagnostics()` JSON, CI or e2e log paths, and the user's own visual confirmation (route, viewport). If there is none, say so in the prompt.

3. **Triage findings.**
   - Read the Verdict line. **NEEDS VISUAL VERIFICATION** → show the `Before READY` list and the Evidence section's `not provided` lines verbatim, and ask whether the user has checked them. Proceed only on an explicit yes.
   - [CRITICAL] **Critical** → abort the ship flow, surface the issues, ask user how to proceed.
   - [WARN] **Should fix** → list them, ask user to confirm shipping anyway OR pause to fix.
   - [NOTE] **Passed / Optional** → proceed.

4. **Draft commit message** in conventional-commit format (`type(scope): description`). Types: `feat`, `fix`, `polish`, `chore`, `docs`, `refactor`. Keep subject under 72 chars. Add a body if the diff touches >2 files. The message describes the change and nothing else — no attribution, co-author, or generated-by trailers of any kind.

5. **Show the message + diff summary** and ask for explicit confirmation before committing.

6. **Stage and commit.** Use `git add` with specific file paths (never `-A` for safety). Use HEREDOC for the commit message to preserve formatting. Hooks may fire — let them. Do not pass `--no-verify` unless the user explicitly asks.

7. **Push to remote.** If the branch has no upstream, use `git push -u origin <branch>`. Report the remote ref.

8. **Offer to open a PR.** If the branch isn't the repo's default branch, ask whether to open a PR via `gh pr create`. Don't open it without confirmation. Use this PR template:
   ```
   ## Summary
   <1-3 bullets>

   ## Test plan
   - [ ] <verification steps>
   ```
   The body is the summary and the test plan — no attribution or generated-by trailers.

Do not skip the premium-review step. Do not commit before user confirms the message. Do not push to the default branch without explicit instruction.
