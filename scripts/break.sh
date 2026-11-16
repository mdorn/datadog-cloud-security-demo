#!/usr/bin/env bash
# Re-arm the demo: re-apply all intentional misconfigurations (after a plan
# and your confirmation) and redeploy the vulnerable baseline image.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

"$ROOT/scripts/preflight.sh"
rearm_infra
ensure_baseline_tag
echo "== redeploy vulnerable baseline image $(baseline_tag)"
"$ROOT/scripts/deploy-image.sh" "$(baseline_tag)"
"$ROOT/scripts/status.sh"
