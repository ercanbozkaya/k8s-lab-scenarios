#!/usr/bin/env bash
# setup.sh — provision the broken/incomplete environment for question 0001.
# Creates deployments in frontend/database/payments namespaces, NO NetworkPolicy.
set -euo pipefail

source "$(dirname "$0")/../../lib/cluster.sh"
source "$(dirname "$0")/../../lib/question.sh"

log_info "Setting up question: ${Q_ID}"
log_info "Question namespace: ${QUESTION_NS}"

# Namespaces needed for this question (web-app in frontend, db in database, plus payments).
for ns in frontend database payments; do
  ensure_namespace "$ns"
  log_info "Namespace '${ns}' ready."
done

# web-app Deployment in frontend namespace.
log_info "Creating web-app deployment in frontend…"
k8s_exec apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: frontend
  labels:
    app: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: nginx
          image: nginxinc/nginx-unprivileged:1.27
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: frontend
spec:
  selector:
    app: web-app
  ports:
    - port: 8080
      targetPort: 8080
EOF

# db Deployment in database namespace.
log_info "Creating db deployment in database…"
k8s_exec apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: database
  labels:
    app: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_PASSWORD
              value: "secret"
          ports:
            - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-svc
  namespace: database
spec:
  selector:
    app: db
  ports:
    - port: 5432
      targetPort: 5432
EOF

# payments Deployment in payments namespace (source of allowed traffic).
log_info "Creating payments deployment in payments…"
k8s_exec apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  namespace: payments
  labels:
    app: payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
        - name: payments-app
          image: nginxinc/nginx-unprivileged:1.27
          ports:
            - containerPort: 8080
EOF

# Create the question's own namespace (clean slate — no NetworkPolicy).
ensure_namespace "$QUESTION_NS"

log_info "Setup complete. No NetworkPolicy was created — that is the candidate's task."