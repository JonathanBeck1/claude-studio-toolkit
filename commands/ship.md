---
description: End-of-build flow for client deliverable changes — premium-review, commit, push.
argument-hint: [optional commit message, otherwise drafted from the diff]
---

Run the canonical ship flow. Commit message hint: $ARGUMENTS (otherwise draft one from the diff).

Steps in order — do not skip:

1. **Snapshot state.** Run `git status` and `git diff --stat`. Confirm there are changes to ship. If working tree is clean, abort with "Nothing to ship."

2. **Run premium-review.** Invoke the `premium-review` subagent (`claude-studio-toolkit:premium-review` when installed as a plugin) against the current diff. It chains threejs-audit + brand-check + the ship checklist. Wait for its punch list.

3. **Triage findings.**
   - [CRITICAL] **Critical** → abort the ship flow, surface the issues, ask user how to proceed.
   - [WARN] **Should fix** → list them, ask user to confirm shipping anyway OR pause to fix.
   - [NOTE] **Passed / Optional** → proceed.

4. **Draft commit message** in conventional-commit format (`type(scope): description`). Types: `feat`, `fix`, `polish`, `chore`, `docs`, `refactor`. Keep subject under 72 chars. Add a body if the diff touches >2 files. Always include the co-author footer your harness specifies (e.g. `Co-Authored-By: Claude <noreply@anthropic.com>`).

5. **Show the message + diff summary** and ask for explicit confirmation before committing.

6. **Stage and commit.** Use `git add` with specific file paths (never `-A` for safety). Use HEREDOC for the commit message to preserve formatting. Hooks may fire — let them. Do not pass `--no-verify` unless the user explicitly asks.

7. **Push to remote.** If the branch has no upstream, use `git push -u origin <branch>`. Report the remote ref.

8. **Offer to open a PR.** If the branch isn't `master`/`main`, ask whether to open a PR via `gh pr create`. Don't open it without confirmation. Use the canonical PR template:
   ```
   ## Summary
   <1-3 bullets>

   ## Test plan
   - [ ] <verification steps>
   ```
   Body must include the Claude Code footer.

Do not skip the premium-review step. Do not commit before user confirms the message. Do not push to master without explicit instruction.
