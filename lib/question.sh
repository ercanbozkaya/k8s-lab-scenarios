# Shared library for question-specific helpers — sourced by setup/validate/cleanup.
# Provides: Q_DIR, Q_ID (derived from metadata.yaml), QUESTION_NS, ARTIFACTS_DIR.
# NOTE: no dependency on yq — uses grep+sed instead for macOS compatibility.

# Derive Q_ID directly from this question's metadata.yaml — never rely on a
# pre-set env var.  This guarantees the namespace always matches the metadata.id.
Q_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract id from metadata.yaml using grep/sed (works on macOS without yq).
Q_ID="$(grep '^id:' "$Q_DIR/metadata.yaml" | sed 's/^id:[[:space:]]*//; s/^"//; s/"$//')"

QUESTION_NS="q-${Q_ID}"

# Per-question artifacts directory (for --with-evidence runs).
ARTIFACTS_DIR="${QUESTION_ARTIFACTS_ROOT:-../.question-artifacts}/${Q_ID}"
