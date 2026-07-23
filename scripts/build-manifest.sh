#!/usr/bin/env bash
# build-manifest.sh — scan questions/*/metadata.yaml and emit _manifest.yaml.
# Usage: ./scripts/build-manifest.sh [questions-dir]
# NOTE: macOS-compatible — no yq dependency (uses grep/sed for YAML parsing).
set -euo pipefail

QUESTION_DIR="${1:-../questions}"
MANIFEST_FILE="../_manifest.yaml"

cd "$QUESTION_DIR"

: > "$MANIFEST_FILE"
echo "questions:" >> "$MANIFEST_FILE"

for meta in */metadata.yaml; do
  [ -f "$meta" ] || continue

  # Extract id using grep/sed (macOS-compatible, no yq).
  id="$(grep '^id:' "$meta" | sed 's/^id:[[:space:]]*//; s/^"//; s/"$//' || true)"

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

  # Emit this question: the id line, then any remaining keys from metadata.yaml.
  echo "  - id: \"${id}\"" >> "$MANIFEST_FILE"

  # Extract and emit non-id keys (weight, difficulty, exam_topics, etc.) indented.
  # Skips the 'id' line and blank/comment lines; supports both scalar and list values.
  while IFS= read -r line; do
    case "$line" in
      id:*|#"") continue ;;   # skip id line and comments
    esac
    key="$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f1)"
    val="$(echo "$line" | sed "s/^${key}:[[:space:]]*//" | sed 's/"//g')"
    echo "    ${key}: ${val}" >> "$MANIFEST_FILE"
  done < <(grep -v '^id:' "$meta" | grep '[^[:space:]]' || true)

done

echo "Manifest written to $MANIFEST_FILE: $(grep -c '^  - id:' "$MANIFEST_FILE") question(s)"
