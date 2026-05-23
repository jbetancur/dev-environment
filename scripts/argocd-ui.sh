#!/usr/bin/env bash
# Prints ArgoCD credentials and optionally opens the UI via port-forward.
# Usage: ./scripts/argocd-ui.sh [cluster-name] [--open]
set -euo pipefail

CLUSTER_NAME="${1:-john}"
CONTEXT="kind-${CLUSTER_NAME}"
PORT=8080

PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  --namespace argocd \
  --context "$CONTEXT" \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d) || true

echo ""
echo "***********************************************************************"
echo "* ArgoCD UI                                                           *"
echo "***********************************************************************"
if [[ -z "$PASSWORD" ]]; then
  echo "  (initial secret deleted — use your current password)"
else
  echo "  Username: admin"
  echo "  Password: ${PASSWORD}"
fi
echo "***********************************************************************"
echo ""

if [[ "${2:-}" == "--open" ]]; then
  echo "==> Starting port-forward on http://localhost:${PORT} (Ctrl-C to stop)..."
  open "http://localhost:${PORT}" 2>/dev/null || true
  kubectl port-forward svc/argocd-server \
    --namespace argocd \
    --context "$CONTEXT" \
    "${PORT}:80"
else
  echo "  To open the UI locally:"
  echo "  ./scripts/argocd-ui.sh ${CLUSTER_NAME} --open"
fi
