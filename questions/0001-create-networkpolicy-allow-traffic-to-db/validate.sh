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
EVIDENCE=false
if [ "${1:-}" = "--with-evidence" ]; then
  EVIDENCE=true
  mkdir -p "$ARTIFACTS_DIR"
fi

log_info "Validating question: ${Q_ID}"
log_info "Question namespace: ${QUESTION_NS}"

# 1. NetworkPolicy must exist in the frontend namespace.
NP_EXISTS=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend -o name 2>/dev/null || true)
[ -n "$NP_EXISTS" ] && [ "${#NP_EXISTS}" -gt 0 ]; _pass=$?; check "policy-exists" \
  "NetworkPolicy allow-traffic-to-db found in frontend namespace" "$_pass"

# 2. Must have ingress rules (the spec has an ingress section).
HAS_INGRESS=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend -o jsonpath='{.spec.ingress}' 2>/dev/null || true)
[ -n "$HAS_INGRESS" ] && [ "${#HAS_INGRESS}" -gt 2 ]; _pass=$?; check "has-ingress-rule" \
  "Policy spec contains an ingress rule entry" "$_pass"

# Extract the JSON of ingress rules.
INGRESS_JSON=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend \
  -o jsonpath='{.spec.ingress[0]}' 2>/dev/null || echo '{}')

# 3. Must allow traffic from the database namespace pods (by podSelector matching app: db).
DB_RULE_EXISTS=false
if echo "$INGRESS_JSON" | yq -e '.from[].podSelector.matchLabels["app"]' &>/dev/null; then
  DB_SELECTOR=$(echo "$INGRESS_JSON" | yq -r '.from[].podSelector.matchLabels["app"]' 2>/dev/null || true)
  if [ "$DB_SELECTOR" = "db" ]; then
    DB_RULE_EXISTS=true
  fi
fi
echo "$DB_RULE_EXISTS"; _pass=$?; check "db-ingress-label" \
  "Ingress rule has a podSelector matching app=db (from database namespace)" "$_pass"

# 4. Must allow all traffic from the payments namespace (namespaceSelector).
PAYMENTS_RULE_EXISTS=false
if echo "$INGRESS_JSON" | yq -e '.from[].namespaceSelector.matchLabels' &>/dev/null; then
  PAYMENTS_NS=$(echo "$INGRESS_JSON" | yq -r '.from[].namespaceSelector.matchLabels' 2>/dev/null || true)
  # A bare namespaceSelector (no app label filter) means "all traffic from this ns".
  # We accept either a bare {} or any namespaceSelector — check that the ns label is empty/absent.
  if [ -z "$PAYMENTS_NS" ] || [ "$PAYMENTS_NS" = "{}" ]; then
    PAYMENTS_RULE_EXISTS=true
  fi
fi
echo "$PAYMENTS_RULE_EXISTS"; _pass=$?; check "payments-namespace-selector" \
  "Ingress rule has a namespaceSelector allowing all traffic from payments namespace" "$_pass"

# 5. Policy podSelector must target the web-app workload in frontend namespace.
WEBAPP_SELECTOR=$(k8s_exec get networkpolicy allow-traffic-to-db -n frontend \
  -o jsonpath='{.spec.podSelector.matchLabels}' 2>/dev/null || echo "")
if echo "$WEBAPP_SELECTOR" | grep -q "app:web-app\|\"app\":\"web-app\"" 2>/dev/null; then
  check "policy-targets-webapp" \
    "PodSelector targets app=web-app in frontend namespace" "true"
else
  check "policy-targets-webapp" \
    "PodSelector targets app=web-app in frontend namespace" "false"
fi

# Summary line — always emitted on stdout (orchestrator reads exit code as truth).
echo "{\"summary\":{\"total\":${TOTAL},\"passed\":${PASSED},\"failed\":$((TOTAL - PASSED))}}"

exit $([ "$PASSED" -eq "$TOTAL" ] && echo 0 || echo 1)
