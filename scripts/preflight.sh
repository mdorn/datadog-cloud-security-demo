#!/usr/bin/env bash
# Guardrail: refuse to continue unless we're pointed at the demo sandbox account.
set -euo pipefail

EXPECTED_ACCOUNT="897722680419"
PROFILE="${AWS_PROFILE:-default}"

actual="$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text 2>/dev/null || true)"

if [[ "$actual" != "$EXPECTED_ACCOUNT" ]]; then
  echo "preflight: ABORT - AWS account is '${actual:-<unknown>}', expected ${EXPECTED_ACCOUNT} (profile: ${PROFILE})" >&2
  exit 1
fi

for v in DD_API_KEY DD_APP_KEY; do
  if [[ -z "${!v:-}" ]]; then
    echo "preflight: ABORT - ${v} is not set" >&2
    exit 1
  fi
done

echo "preflight: OK - account ${actual}, profile ${PROFILE}, Datadog keys present"
