#!/usr/bin/env bash
# After a demo: undo live fixes, restore the vulnerable dependency versions on
# main through a revert PR, redeploy the baseline image, list Jira issues to close.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

"$ROOT/scripts/preflight.sh"
rearm_infra

echo "== app/pom.xml on main vs vulnerable baseline"
git -C "$ROOT" fetch -q origin main
base_commit=$(git -C "$ROOT" rev-parse "$(baseline_tag)")
if git -C "$ROOT" diff --quiet "$base_commit" origin/main -- app/pom.xml; then
  echo "main already pins the vulnerable versions; no revert PR needed"
else
  branch="reset/vulnerable-deps-$(date +%Y%m%d-%H%M)"
  wt=$(mktemp -d)
  git -C "$ROOT" worktree add -q -b "$branch" "$wt" origin/main
  git -C "$wt" checkout -q "$base_commit" -- app/pom.xml
  git -C "$wt" commit -q -m "Restore vulnerable demo dependency versions

Reverts app/pom.xml to the demo baseline ($(baseline_tag)) so the next
build is vulnerable again. Created by make reset."
  git -C "$wt" --no-pager diff HEAD~1 -- app/pom.xml
  if confirm "Push $branch and open a revert PR on $GH_REPO?"; then
    git -C "$wt" push -q -u origin "$branch"
    gh pr create --repo "$GH_REPO" --base main --head "$branch" \
      --title "Reset demo: restore vulnerable dependency versions" \
      --body "Restores \`app/pom.xml\` to the demo baseline (\`$(baseline_tag)\`). Merging rebuilds a vulnerable image. Created by \`make reset\`."
  else
    echo "skipped; local branch $branch kept"
  fi
  git -C "$ROOT" worktree remove --force "$wt"
fi

ensure_baseline_tag
echo "== redeploy vulnerable baseline image $(baseline_tag)"
"$ROOT/scripts/deploy-image.sh" "$(baseline_tag)"
jira_open_issues_hint
