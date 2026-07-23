# Shared library for cluster interactions — sourced by question scripts, never called directly.
# Provides: k8s_exec, ensure_namespace, delete_namespace, logging helpers.

export CONTROLLER_NAME="${CONTROLLER_NAME:-k8slab-controller}"
export LAB_REPO_PATH="${LAB_REPO_PATH:-}"

# If the infra repo is available at $LAB_REPO_PATH, source its config.sh
# so question scripts get the same defaults (VM names, FQDNs, etc.).
if [ -n "$LAB_REPO_PATH" ] && [ -f "$LAB_REPO_PATH/config.sh" ]; then
  source "$LAB_REPO_PATH/config.sh"
fi

# Execute kubectl inside the controller VM.
# Usage: k8s_exec get nodes -n kube-system --kubeconfig /etc/kubernetes/admin.conf
# NOTE: this builds the full path explicitly — never embeds KUBECONFIG into itself.
k8s_exec() {
  multipass exec "$CONTROLLER_NAME" -- sudo kubectl \
    --kubeconfig "/etc/kubernetes/admin.conf" "$@"
}

# Create a namespace if it doesn't exist — idempotent, single SSH session.
ensure_namespace() { k8s_exec create namespace "$1" 2>/dev/null || true; }

# Delete a namespace — ignore-if-gone, so cleanup.sh exits 0 always.
delete_namespace() { k8s_exec delete namespace "$1" --ignore-not-found=true; }

# Logging — use these instead of raw echo in question scripts.
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }