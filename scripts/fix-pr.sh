#!/usr/bin/env bash
# Demo helper: open a PR with a one-line dependency bump.
# Usage: fix-pr.sh <log4j|commons-text|jackson> [--dry-run]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

dep="${1:-}"; dry="${2:-}"
case "$dep" in
  log4j)        prop=log4j.version;            to=2.26.1; why="Log4Shell CVE-2021-44228 and related log4j CVEs" ;;
  commons-text) prop=commons-text.version;     to=1.15.0; why="Text4Shell CVE-2022-42889" ;;
  jackson)      prop=jackson-databind.version; to=2.23.0; why="jackson-databind deserialization CVEs" ;;
  *) echo "usage: $0 <log4j|commons-text|jackson> [--dry-run]" >&2; exit 2 ;;
esac

git -C "$ROOT" fetch -q origin main
branch="fix/$dep-$(date +%Y%m%d-%H%M)"
wt=$(mktemp -d)
trap 'git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true' EXIT
git -C "$ROOT" worktree add -q -b "$branch" "$wt" origin/main

from=$(sed -nE "s|.*<$prop>([^<]+)</$prop>.*|\1|p" "$wt/app/pom.xml")
[[ -n "$from" ]] || { echo "property $prop not found in app/pom.xml" >&2; exit 1; }
[[ "$from" != "$to" ]] || { echo "$prop is already $to on main"; exit 0; }
sed -i.bak -E "s|<$prop>$from</$prop>|<$prop>$to</$prop>|" "$wt/app/pom.xml" && rm -f "$wt/app/pom.xml.bak"
[[ "$(git -C "$wt" diff --numstat -- app/pom.xml)" == $'1\t1\tapp/pom.xml' ]] || { echo "unexpected diff" >&2; exit 1; }

git -C "$wt" commit -q -am "Bump $dep $from -> $to

Fixes $why."
git -C "$wt" --no-pager show --stat --format='%s' HEAD
git -C "$wt" --no-pager diff HEAD~1 -- app/pom.xml

if [[ "$dry" == "--dry-run" ]]; then
  echo "dry run: nothing pushed"
  git -C "$ROOT" worktree remove --force "$wt"; git -C "$ROOT" branch -q -D "$branch"
  exit 0
fi
if confirm "Push $branch and open a PR on $GH_REPO?"; then
  git -C "$wt" push -q -u origin "$branch"
  gh pr create --repo "$GH_REPO" --base main --head "$branch" \
    --title "Bump $dep to $to" \
    --body "One-line dependency bump: \`$prop\` $from -> $to. Fixes $why. Merging rebuilds and redeploys the image."
else
  echo "skipped; local branch $branch kept"
fi
