#!/usr/bin/env bash
# Prints the ID of the Datadog application key in DD_APP_KEY (matched by last4).
# The ID is not secret; the key value is never printed.
set -euo pipefail
: "${DD_API_KEY:?}" "${DD_APP_KEY:?}"
DD_SITE="${DD_SITE:-datadoghq.com}"

curl -sfg \
  -H "DD-API-KEY: ${DD_API_KEY}" -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  "https://api.${DD_SITE}/api/v2/current_user/application_keys?page[size]=100" |
  LAST4="${DD_APP_KEY: -4}" python3 -I -c '
import json, os, sys
ids = [k["id"] for k in json.load(sys.stdin)["data"] if k["attributes"].get("last4") == os.environ["LAST4"]]
if len(ids) != 1:
    sys.exit(f"dd-app-key-id: expected 1 matching key, found {len(ids)}")
print(ids[0])
'
