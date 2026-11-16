#!/usr/bin/env bash
# Shared helpers for break/reset/fix-pr. Source, don't execute.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION=us-east-2
ECR_REPO=cspm-remed-demo-app
GH_REPO=mdorn/datadog-cloud-security-demo
JIRA_URL=https://textmethod.atlassian.net
export AWS_PROFILE="${AWS_PROFILE:-default}" AWS_REGION="$REGION"

confirm() {
  local answer
  if [[ ! -t 0 ]]; then
    echo "confirm: no terminal for confirmation; aborting" >&2
    return 1
  fi
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

baseline_tag() { tr -d '[:space:]' < "$ROOT/DEMO_BASELINE_TAG"; }

# Plan infra/vulnerable, summarize, and apply only after confirmation.
rearm_infra() {
  local dir="$ROOT/infra/vulnerable" rc=0
  echo "== terraform plan: infra/vulnerable"
  terraform -chdir="$dir" plan -input=false -no-color -out=tfplan -detailed-exitcode > "$dir/.plan.log" 2>&1 || rc=$?
  case $rc in
    0) echo "nothing to re-arm (no changes)"; rm -f "$dir/tfplan" "$dir/.plan.log"; return 0 ;;
    2) grep -E '^  # |^Plan:' "$dir/.plan.log" | grep -v 'will be read during apply' ;;
    *) cat "$dir/.plan.log" >&2; rm -f "$dir/tfplan" "$dir/.plan.log"; return 1 ;;
  esac
  if confirm "Apply this plan to re-arm the misconfigurations?"; then
    terraform -chdir="$dir" apply -input=false -no-color "$dir/tfplan" | grep -E 'complete|Error'
  else
    echo "skipped apply"
  fi
  rm -f "$dir/tfplan" "$dir/.plan.log"
}

# Keep the vulnerable baseline image from ECR lifecycle expiry by giving it a
# permanent 'baseline' tag (tags are immutable, but adding a new one is allowed).
ensure_baseline_tag() {
  local tag current manifest
  tag="$(baseline_tag)"
  current=$(aws ecr describe-images --repository-name "$ECR_REPO" --image-ids imageTag=baseline \
    --query 'imageDetails[0].imageTags' --output text 2>/dev/null || true)
  if [[ "$current" == *"$tag"* ]]; then
    return 0
  elif [[ -n "$current" && "$current" != "None" ]]; then
    echo "warning: ECR tag 'baseline' points at [$current], not $tag" >&2
    return 0
  fi
  manifest=$(aws ecr batch-get-image --repository-name "$ECR_REPO" --image-ids imageTag="$tag" \
    --accepted-media-types application/vnd.oci.image.index.v1+json application/vnd.docker.distribution.manifest.list.v2+json application/vnd.oci.image.manifest.v1+json application/vnd.docker.distribution.manifest.v2+json \
    --query 'images[0].imageManifest' --output text)
  aws ecr put-image --repository-name "$ECR_REPO" --image-tag baseline --image-manifest "$manifest" >/dev/null
  echo "tagged $ECR_REPO:$tag as 'baseline'"
}

jira_open_issues_hint() {
  local jql='project = KAN AND summary ~ "cspm-remed-demo" AND statusCategory != Done ORDER BY created DESC'
  local enc
  enc=$(python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$jql")
  echo "== Open demo Jira issues to close"
  echo "JQL:  $jql"
  echo "Link: $JIRA_URL/issues/?jql=$enc"
}
