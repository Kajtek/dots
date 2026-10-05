---
description: Fetch open review comments on the current MR/PR and address each one
---

Address the open review comments on the current branch's MR/PR.

1. Find the MR/PR for the current branch (`glab mr view --comments` or `gh pr view --comments` / `gh api` for review threads). If neither CLI works, ask me to paste the comments.
2. List every unresolved thread with file/line and a one-line summary. Propose a plan: for each thread, either a code change or a reasoned reply — per the "Responding to review comments" section of the user-level CLAUDE.md.
3. After my approval, implement the changes as `git commit --fixup <sha>` commits targeting the commit each fix belongs to, running the relevant tests to verify each fix before calling it done.
4. Draft the per-thread replies (what changed + short SHA) for me to post, and finish with a summary of what changed since the last review round. Do not push, resolve threads, or post replies yourself without confirmation.

$ARGUMENTS
