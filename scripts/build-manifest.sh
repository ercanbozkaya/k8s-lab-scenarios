#!/usr/bin/env bash
# build-manifest.sh — scan questions/*/metadata.yaml and emit _manifest.yaml.
# Usage: ./scripts/build-manifest.sh [questions-dir]
set -euo pipefail

QUESTION_DIR="${1:-../questions}"
MANIFEST_FILE="../_manifest.yaml"

cd "$QUESTION_DIR"

: > "$MANIFEST_FILE"
echo "questions:" >> "$MANIFEST_FILE"

for meta in */metadata.yaml; do
  [ -f "$meta" ] || continue
  id="$(yq -r '.id // empty' "$meta")"

  # Skip entries with no id (allow questions without required fields otherwise).
  [ -n "$id" ] || { log_warn "Skipping $meta: no id found"; continue; }

  # DNS-1123 + length validation on q-<id> (Fix #4).
  ns="q-${id}"
  if ! echo "$ns" | grep -Eq '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'; then
    log_error "Invalid namespace name '$ns' (id='$id') — does not match DNS-1123 label pattern"
    continue
  fi
  if [ "${#ns}" -gt 63 ]; then
    log_error "Namespace name '$ns' exceeds 63 chars (${#ns}) — id='$id'"
    continue
  fi

  # Emit YAML entries from metadata.yaml: skip 'id' key (already in the list item),
  # indent each remaining key by 4 spaces under the list item.
  EXTRA=$(yq '. | del(.id) | to_entries[] | "    \(.key): \(.value)"' "$meta" 2>/dev/null || true)

  echo "  - id: \"${id}\"" >> "$MANIFEST_FILE"
  if [ -n "$EXTRA" ]; then
    echo "$EXTRA" >> "$MANIFEST_FILE"
  fi

done

echo "Manifest written to $MANIFEST_FILE: $(grep -c '^  - id:' "$MANIFEST_FILE") question(s)"
