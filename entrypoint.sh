#!/usr/bin/env bash
set -Eeuo pipefail

python --version
sphinx-build --version
node --version
playwright --version

# Operate relative to the working directory so the same entrypoint works with
# any workspace mount (/workspace locally, /github/workspace in the Action).
ws="$(pwd)"

# Seed .cache_confluence_publish from the manifest if the cache is absent or
# empty but the manifest records a page id from a prior publish.  This ensures
# the builder updates the existing page rather than creating a duplicate when
# the output directory has been cleared while the manifest survived.
_restore_publish_cache() {
    local id="$1" out="$2"
    local cache="$out/confluence/$id/.cache_confluence_publish"
    local manifest_file="$out/manifests/$id.json"
    [ -f "$manifest_file" ] || return 0
    if [ -f "$cache" ] && [ "$(cat "$cache")" != "{}" ]; then
        return 0
    fi
    local stored_id
    stored_id=$(python3 -c "
import json, sys
try:
    m = json.load(open(sys.argv[1]))
    print(m.get('outputs', {}).get('confluence', {}).get('pageId', ''))
except Exception:
    print('')
" "$manifest_file" 2>/dev/null) || stored_id=""
    [ -n "$stored_id" ] || return 0
    printf '{"index": "%s"}' "$stored_id" > "$cache"
    echo "[$id] restored publish cache from manifest (pageId=$stored_id)"
}

process_runbook() {
    local path="$1"
    local id="$2"
    local build_dir="/tmp/runbook-build/$id"
    local out="$ws/output"

    rm -rf "$build_dir"
    mkdir -p \
        "$build_dir/src/_static" \
        "$build_dir/dt-confluence" \
        "$build_dir/dt-html" \
        "$out/confluence/$id" \
        "$out/html/$id" \
        "$out/pdf" \
        "$out/manifests"

    _restore_publish_cache "$id" "$out"

    cp "$path" "$build_dir/src/index.md"

    local assets="${path%.runbook.md}.assets"
    [ -d "$assets" ] && cp -r "$assets" "$build_dir/src/$(basename "$assets")"

    cat > "$build_dir/src/_static/runbook.css" << 'CSS'
body { font-family: sans-serif; max-width: 960px; margin: 0 auto; padding: 1em 2em; }
.runbook-metadata dl { background: #f5f5f5; padding: .75em 1em; border-left: 3px solid #888; }
.runbook-cross-format-links { padding: .4em 0; font-size: .9em; color: #444; }
figure.runbook-image { margin: 1em 0; }
figure.runbook-image img { max-width: 100%; height: auto; }
figure.runbook-image figcaption { font-size: .85em; color: #555; font-style: italic; }
@media print {
  .runbook-cross-format-links { display: none; }
  @page { size: A4; margin: 20mm; }
  body { max-width: 100%; padding: 0; }
}
CSS

    local rel_path
    rel_path="${path#$ws/}"

    # Cross-format links are relative to the html output location so the
    # rendered bytes do not depend on where the workspace is mounted.
    cat > "$build_dir/src/conf.py" << CONF
from sphinx_runbook.defaults import *
runbook_source_path = "$build_dir/src/index.md"
runbook_cross_format_links = {
    "html": "index.html",
    "pdf": "../../pdf/$id.pdf",
    "source": "../../../$rel_path",
    "confluence": "../../confluence/$id",
}
CONF

    if [ -n "${CONFLUENCE_SERVER_URL:-}" ]; then
        cat >> "$build_dir/src/conf.py" << LIVE
confluence_publish = True
confluence_server_url = "${CONFLUENCE_SERVER_URL}"
confluence_space_name = "${CONFLUENCE_SPACE_NAME:-RBK}"
confluence_server_user = "${CONFLUENCE_USERNAME:-}"
confluence_api_token = "${CONFLUENCE_API_TOKEN:-}"
confluence_page_generation_notice = True
LIVE
        if [ -n "${CONFLUENCE_PARENT_PAGE:-}" ]; then
            printf 'confluence_parent_page = "%s"\n' "${CONFLUENCE_PARENT_PAGE}" >> "$build_dir/src/conf.py"
        fi
    fi

    # The call site runs this function with errexit suppressed (bash ignores
    # -e for a function body invoked from a conditional), so each step that
    # must fail the runbook guards its own status explicitly.
    echo "[$id] building confluence"
    sphinx-build -b confluence \
        -d "$build_dir/dt-confluence" \
        "$build_dir/src" "$out/confluence/$id" || return $?

    echo "[$id] building html"
    sphinx-build -b html \
        -d "$build_dir/dt-html" \
        "$build_dir/src" "$out/html/$id" || return $?

    echo "[$id] rendering pdf"
    node "$ws/render-pdf.mjs" \
        --input "$out/html/$id/index.html" \
        --output "$out/pdf/$id.pdf" || return $?

    local src_hash html_hash pdf_hash
    src_hash="sha256:$(sha256sum "$path" | awk '{print $1}')" || return $?
    html_hash="sha256:$(sha256sum "$out/html/$id/index.html" | awk '{print $1}')" || return $?
    pdf_hash="sha256:$(sha256sum "$out/pdf/$id.pdf" | awk '{print $1}')" || return $?

    local page_id=""
    if [ -n "${CONFLUENCE_SERVER_URL:-}" ]; then
        page_id=$(python3 -c "
import json, sys
try:
    cache = json.load(open(sys.argv[1]))
    print(cache.get('index', ''))
except Exception:
    print('')
" "$out/confluence/$id/.cache_confluence_publish" 2>/dev/null) || page_id=""
    fi

    local confluence_obj
    if [ -n "$page_id" ]; then
        confluence_obj="\"pageId\": \"$page_id\", \"url\": \"${CONFLUENCE_SERVER_URL}/spaces/${CONFLUENCE_SPACE_NAME:-RBK}/pages/$page_id\", \"path\": \"output/confluence/$id\""
    else
        confluence_obj="\"path\": \"output/confluence/$id\""
    fi

    cat > "$out/manifests/$id.json" << MANIFEST
{
  "schemaVersion": 1,
  "id": "$id",
  "source": { "path": "$rel_path" },
  "outputs": {
    "confluence": { $confluence_obj },
    "html": { "path": "output/html/$id/index.html" },
    "pdf": { "path": "output/pdf/$id.pdf" }
  },
  "hashes": {
    "source": "$src_hash",
    "html": "$html_hash",
    "pdf": "$pdf_hash"
  }
}
MANIFEST

    echo "[$id] complete"
}

mkdir -p "$ws/output/manifests"

# Default failure policy is "continue": process every runbook, then fail at
# the end if any failed (§14.5).
failures=()

while IFS= read -r path; do
    id=$(awk 'NR==1{if($0!="---")exit} NR>1{if(/^---/)exit; if(/^id:/){sub(/^id:[[:space:]]*/,""); print; exit}}' "$path")
    echo "[$id] discovered: $path"
    if ! process_runbook "$path" "$id"; then
        failures+=("$id")
        echo "[$id] FAILED"
    fi
done < <(find "$ws" -name "*.runbook.md" | sort)

python3 -c "
import json, glob, os
out = os.path.join(os.getcwd(), 'output', 'manifests')
records = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(out, '*.json')))]
print(json.dumps({'schemaVersion': 1, 'runbooks': records}, indent=2))
" > "$ws/output/manifest.json"

echo "aggregate manifest: $ws/output/manifest.json"

if [ ${#failures[@]} -gt 0 ]; then
    echo "failed runbooks: ${failures[*]}"
    exit 1
fi
