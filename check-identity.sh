#!/usr/bin/env bash
# Publish the fixture runbook twice from separate isolated Docker invocations
# and assert the Confluence page id is unchanged.
#
# Each run gets a fresh /tmp (new container), but output/confluence/<id>/ is
# preserved through the volume mount.  The builder reads pageId from
# .cache_confluence_publish on the second run and updates the same page.
#
# Prerequisites:
#   make build
#   export CONFLUENCE_SERVER_URL CONFLUENCE_SPACE_NAME CONFLUENCE_USERNAME CONFLUENCE_API_TOKEN
#   optionally: export CONFLUENCE_PARENT_PAGE
set -Eeuo pipefail

IMAGE=runbook-publisher:0.1.0
WORKSPACE="$(cd "$(dirname "$0")" && pwd)"

_page_id() {
    python3 -c "
import json
m = json.load(open('${WORKSPACE}/output/manifests/aws-s3-upload-error.json'))
print(m.get('outputs', {}).get('confluence', {}).get('pageId', ''))
"
}

_run() {
    docker run --rm -u "$(id -u):$(id -g)" \
        -v "${WORKSPACE}:/workspace" \
        -e CONFLUENCE_SERVER_URL \
        -e CONFLUENCE_SPACE_NAME \
        -e CONFLUENCE_PARENT_PAGE \
        -e CONFLUENCE_USERNAME \
        -e CONFLUENCE_API_TOKEN \
        "${IMAGE}"
}

echo "=== publish 1 ==="
_run
id1=$(_page_id)
[ -n "$id1" ] || { echo "FAIL: page id not captured after publish 1 — credentials may be missing"; exit 1; }
echo "pageId: ${id1}"

echo "=== publish 2 (fresh container, persistent output/confluence cache) ==="
_run
id2=$(_page_id)
echo "pageId: ${id2}"

if [ "$id1" = "$id2" ]; then
    echo "PASS: same page id (${id1}) — identity preserved via .cache_confluence_publish"
else
    echo "FAIL: id changed (${id1} → ${id2}) — duplicate may have been created"
    exit 1
fi
