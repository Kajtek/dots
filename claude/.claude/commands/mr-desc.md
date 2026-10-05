---
description: Draft an MR/PR title and description for the current branch in my standard format
---

Draft a Merge Request title and description for the current branch.

1. Determine the base: `git merge-base origin/main HEAD` (fall back to `main`). Review `git log` and `git diff --stat` from there to HEAD, and read the important diffs.
2. Check for a repo MR/PR template (`.gitlab/merge_request_templates/`, `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`). If one exists, fill it in; otherwise use my default structure from the "Merge Request title and description" section of the user-level CLAUDE.md (Summary / Changes / Testing / Notes, Conventional Commits title, closing keywords for the tracked issue).
3. For the Testing section, report only what was actually run in this branch's history or session — state plainly what was not tested.
4. Output the title and description in a markdown code block for copy-paste. Do NOT create or edit the MR unless I explicitly ask; if I do ask, confirm first.

$ARGUMENTS
