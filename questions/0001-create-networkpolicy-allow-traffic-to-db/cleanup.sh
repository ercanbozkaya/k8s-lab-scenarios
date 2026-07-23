#!/usr/bin/env bash
# cleanup.sh — remove everything created by setup.sh for question 0001.
set -euo pipefail

source "$(dirname "$0")/../../lib/cluster.sh"
source "$(dirname "$0")/../../lib/question.sh"

log_info "Cleaning up question: ${Q_ID}"
log_info "Question namespace: ${QUESTION_NS}"

# Delete namespaces created for this question (ignore-not-found so re-runs are safe).
for ns in frontend database payments; do
  delete_namespace "$ns"
  log_info "Namespace '${ns}' deleted (or already absent)."
done

# Delete the question's own namespace.
delete_namespace "$QUESTION_NS"
log_info "Question namespace '${QUESTION_NS}' deleted (or already absent)."

# Remove evidence artifacts if they were captured.
if [ -n "${ARTIFACTS_DIR:-}" ] && [ -d "$ARTIFACTS_DIR" ]; then
  rm -rf "$ARTIFACTS_DIR"
  log_info "Artifacts directory removed."
fi

log_info "Cleanup complete."