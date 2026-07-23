#!/usr/bin/env bash
# validate.sh — grade question 0001: check allow-traffic-to-db NetworkPolicy exists
# and has the required ingress rules (db by label + payments namespace).
set -euo pipefail

source "$(dirname "$0")/../../lib/cluster.sh"
source "$(dirname "$0")/../../lib/question.sh"

TOTAL=0
PASSED=0

check() {
  local name="$1" detail="$2" pass="${3:-false}"
  TOTAL=$((TOTAL + 1))
  if [ "$pass" = "true" ]; then
    PASSED=$((PASSED + 1))
    echo "{\"check\":\"${name}\",\"status\":\"PASS\",\"detail\":\"${detail}\"}"
  else
    echo "{\"check\":\"${name}\",\"status\":\"FAIL\",\"detail\":\"${detail}\"}"
  fi
}

# Collect evidence files if --with-evidence is passed.
if [ "${1:-}" = "--with-evidence" ]; then
  mkdir -p "$ARTIFACTS_DIR"
fi

log_info "Validating question: ${Q_ID}"
log_info "Question namespace: ${QUESTION_NS}"

# 1. NetworkPolicy must exist in the frontend namespace.
NP_EXISTS=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend -o name 2>/dev/null || true)
if [ -n "$NP_EXISTS" ]; then
  check "policy-exists" "NetworkPolicy allow-traffic-to-db found in frontend namespace" "true"
else
  check "policy-exists" "NetworkPolicy allow-traffic-to-db not found in frontend namespace" "false"
fi

# 2. Must have ingress rules (the spec has an ingress section).
HAS_INGRESS=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend \
  -o jsonpath='{.spec.ingress}' 2>/dev/null || true)
if [ -n "$HAS_INGRESS" ] && [ "${#HAS_INGRESS}" -gt 2 ]; then
  check "has-ingress-rule" "Policy spec contains an ingress rule entry" "true"
else
  check "has-ingress-rule" "Policy spec has no ingress rule entry (or policy missing)" "false"
fi

# Extract the JSON of ingress rules for deeper checks.
INGRESS_JSON=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend \
  -o jsonpath='{.spec.ingress[0]}' 2>/dev/null || echo '{}')

# 3. Must allow traffic from the database namespace pods (podSelector matching app: db).
if echo "$INGRESS_JSON" | jq -e '.from[] | select(.podSelector.matchLabels.app == "db")' &>/dev/null; then
  check "db-ingress-label" "Ingress rule has a podSelector matching app=db (from database namespace)" "true"
else
  check "db-ingress-label" "Ingress rule missing podSelector matching app=db" "false"
fi

# 4. Must allow all traffic from the payments namespace (bare namespaceSelector).
if echo "$INGRESS_JSON" | jq -e '.from[] | select(.namespaceSelector.matchLabels == {} or .namespaceSelector.matchLabels == null)' &>/dev/null; then
  check "payments-namespace-selector" "Ingress rule has a namespaceSelector allowing all traffic from payments namespace" "true"
else
  check "payments-namespace-selector" "Ingress rule missing namespaceSelector for payments namespace (or has label filters)" "false"
fi

# 5. Policy podSelector must target the web-app workload in frontend namespace.
WEBAPP_SELECTOR=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend \
  -o jsonpath='{.spec.podSelector.matchLabels}' 2>/dev/null || echo "")
if echo "$WEBAPP_SELECTOR" | grep -q "app:web-app\|\"app\":\"web-app\"" 2>/dev/null; then
  check "policy-targets-webapp" "PodSelector targets app=web-app in frontend namespace" "true"
else
  check "policy-targets-webapp" "PodSelector does not target app=web-app (or policy missing)" "false"
fi

# Summary line — always emitted on stdout. Exit code is the truth: 0=all pass, 1=any fail.
echo "{\"summary\":{\"total\":${TOTAL},\"passed\":${PASSED},\"failed\":$((TOTAL - PASSED))}}"

if [ "$PASSED" -eq "$TOTAL" ]; then
  log_info "All ${TOTAL} checks passed."
else
  log_warn "${PASSED}/${TOTAL} checks passed, $((TOTAL - PASSED)) failed."
fi

exit $([ "$PASSED" -eq "$TOTAL" ] && echo 0 || echo 1)