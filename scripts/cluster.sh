#!/usr/bin/env bash
# scripts/cluster.sh
#
# Bootstraps a local kind cluster with Cilium CNI and ArgoCD.
# ArgoCD then manages everything else (Envoy Gateway, cert-manager, monitoring)
# by syncing manifests from this repo.
#
# Usage:
#   ./scripts/cluster.sh <name>          # create cluster + bootstrap ArgoCD
#   ./scripts/cluster.sh <name> --test   # also run Cilium connectivity tests
#   ./scripts/cluster.sh <name> --delete # tear the cluster down
#
# Prerequisites:
#   - user.conf populated (copy from user.conf.example)
#   - k8s/cluster.env populated with your domain values
#   - Git remote set (ArgoCD syncs from the remote)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_CONFIG="${SCRIPT_DIR}/../dotfiles/.config/kind/cluster.yaml"
MANIFESTS_DIR="${SCRIPT_DIR}/../k8s"

# Source cluster.env defaults (placeholder values committed to the repo),
# then overlay with user.conf so your real values take precedence.
CLUSTER_ENV="${MANIFESTS_DIR}/cluster.env"
if [[ -f "$CLUSTER_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$CLUSTER_ENV"
fi

USER_CONF="${SCRIPT_DIR}/../user.conf"
if [[ -f "$USER_CONF" ]]; then
  # shellcheck source=/dev/null
  source "$USER_CONF"
fi

# -- versions & release names ------------------------------------------------
# https://github.com/cilium/cilium/releases
CILIUM_RELEASE="cilium"
CILIUM_NS="kube-system"
# https://github.com/argoproj/argo-helm/releases?q=argo-cd
ARGOCD_VERSION="7.8.26"
ARGOCD_NS="argocd"
# Local registry
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

if [[ $# -lt 1 || "${1:-}" == --* ]]; then
  echo "Usage: ./scripts/cluster.sh <cluster-name> [--no-test] [--delete]"
  exit 1
fi
CLUSTER_NAME="$1"
shift

DELETE=false
RUN_TESTS=false
for arg in "$@"; do
  case "$arg" in
    --delete) DELETE=true ;;
    --test)   RUN_TESTS=true ;;
    *) echo "Unknown argument: $arg"
       echo "Usage: ./scripts/cluster.sh <cluster-name> [--test] [--delete]"
       exit 1 ;;
  esac
done

# -- helpers -----------------------------------------------------------------
brew_formula() {
  case "$1" in
    cilium) echo "cilium-cli" ;;
    *)      echo "$1" ;;
  esac
}

require() {
  local bin="$1"
  if ! command -v "$bin" &>/dev/null; then
    local formula; formula="$(brew_formula "$bin")"
    echo "  ✗ '$bin' not found"
    if command -v brew &>/dev/null; then
      read -rp "  Install '$formula' via Homebrew now? (y/N) " yn
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        brew install "$formula"
      else
        echo "  Run: brew install $formula"; exit 1
      fi
    else
      echo "  Run: brew install $formula"; exit 1
    fi
  fi
}

delete_cluster() {
  echo "==> Deleting kind cluster '$CLUSTER_NAME'..."
  kind delete cluster --name "$CLUSTER_NAME"
  if [[ -n "$(kind get clusters 2>/dev/null)" ]]; then
    echo "  Other kind clusters still running — keeping registry '$REGISTRY_NAME'"
  else
    if docker inspect "$REGISTRY_NAME" &>/dev/null; then
      docker rm -f "$REGISTRY_NAME"
      echo "  ✓ Registry '$REGISTRY_NAME' removed"
    fi
  fi
  echo "Done."
}

if [[ "$DELETE" == true ]]; then
  delete_cluster
  exit 0
fi

# -- pre-flight --------------------------------------------------------------
echo "==> Checking prerequisites..."
require kind
require kubectl
require helm
require cilium

if ! docker info &>/dev/null; then
  echo "  ✗ Docker is not running — start Docker Desktop first"
  exit 1
fi

# Validate required vars
missing=()
for var in ACME_EMAIL ACME_DOMAIN ACME_SUBDOMAIN CLOUDFLARE_TOKEN ARGOCD_REPO_URL; do
  [[ -z "${!var:-}" ]] && missing+=("$var")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo ""
  echo "  ✗ Missing required variables:"
  for var in "${missing[@]}"; do
    echo "      $var"
  done
  echo ""
  echo "  Set ACME_EMAIL, CLOUDFLARE_TOKEN in user.conf"
  echo "  Set ACME_DOMAIN, ACME_SUBDOMAIN, ARGOCD_REPO_URL in k8s/cluster.env"
  exit 1
fi
echo "  ✓ All prerequisites met"

# Bail out cleanly if the cluster already exists
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ""
  echo "  Cluster '$CLUSTER_NAME' already exists."
  echo "  To rebuild: ./scripts/cluster.sh $CLUSTER_NAME --delete && ./scripts/cluster.sh $CLUSTER_NAME"
  exit 0
fi

# Derive computed values from what was sourced
ACME_WILDCARD="*.${ACME_SUBDOMAIN}.${ACME_DOMAIN}"
ACME_BASE="${ACME_SUBDOMAIN}.${ACME_DOMAIN}"


# -- local registry ----------------------------------------------------------
echo ""
echo "==> Setting up local registry ($REGISTRY_NAME on localhost:$REGISTRY_PORT)..."
if docker inspect "$REGISTRY_NAME" &>/dev/null; then
  echo "  ✓ Registry already running"
else
  docker run -d \
    --restart=always \
    -p "127.0.0.1:${REGISTRY_PORT}:5000" \
    --network bridge \
    --name "$REGISTRY_NAME" \
    registry:2
  echo "  ✓ Registry started"
fi

# -- create cluster ----------------------------------------------------------
echo ""
echo "==> Creating kind cluster '$CLUSTER_NAME' (no CNI, no kube-proxy)..."
kind create cluster --name "$CLUSTER_NAME" --config "$CLUSTER_CONFIG"

docker network connect "kind" "$REGISTRY_NAME" 2>/dev/null || true

for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
  cat <<EOF | docker exec -i "$node" tee "/etc/containerd/certs.d/localhost:${REGISTRY_PORT}/hosts.toml" > /dev/null
[host."http://${REGISTRY_NAME}:5000"]
EOF
done

kubectl apply --context "kind-${CLUSTER_NAME}" \
  -f "${MANIFESTS_DIR}/registry/local-registry-hosting.yaml"
echo "  ✓ Registry wired — push to localhost:${REGISTRY_PORT}/myimage"

# -- Gateway API CRDs --------------------------------------------------------
# Must be installed before Cilium so the operator finds them on startup.
# Pinned to the same version as the Envoy Gateway ArgoCD Application.
echo ""
echo "==> Installing Gateway API + Envoy Gateway CRDs..."
helm template gateway-crds oci://docker.io/envoyproxy/gateway-crds-helm \
  --kube-context "kind-${CLUSTER_NAME}" \
  --version "v1.7.2" \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=experimental \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f - --context "kind-${CLUSTER_NAME}"
echo "  ✓ Gateway API CRDs installed"

# -- Cilium ------------------------------------------------------------------
echo ""
echo "==> Adding Cilium Helm repo..."
helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update cilium

echo ""
echo "==> Installing Cilium..."
CONTROL_PLANE_NODE="$(kind get nodes --name "$CLUSTER_NAME" | grep control-plane)"
API_SERVER_IP="$(docker inspect "$CONTROL_PLANE_NODE" \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
API_SERVER_PORT=6443

helm upgrade --install "$CILIUM_RELEASE" cilium/cilium \
  --namespace "$CILIUM_NS" \
  --kube-context "kind-${CLUSTER_NAME}" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --set k8sServicePort="${API_SERVER_PORT}" \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set gatewayAPI.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true

echo ""
echo "==> Waiting for Cilium to be ready (this can take ~90 s)..."
kubectl rollout status daemonset/cilium \
  --namespace "$CILIUM_NS" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
kubectl rollout status deployment/cilium-operator \
  --namespace "$CILIUM_NS" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
kubectl rollout status daemonset/cilium-envoy \
  --namespace "$CILIUM_NS" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
kubectl rollout status deployment/hubble-relay \
  --namespace "$CILIUM_NS" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
kubectl rollout status deployment/hubble-ui \
  --namespace "$CILIUM_NS" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
cilium status --context "kind-${CLUSTER_NAME}"

# -- metrics-server ----------------------------------------------------------
echo ""
echo "==> Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --kube-context "kind-${CLUSTER_NAME}" \
  --set args={--kubelet-insecure-tls}
echo "  ✓ metrics-server installed"

# -- Secrets (created before ArgoCD so apps can reference them immediately) --
echo ""
echo "==> Creating cluster secrets..."

# Cloudflare API token for cert-manager DNS-01
kubectl create namespace cert-manager \
  --context "kind-${CLUSTER_NAME}" \
  --dry-run=client -o yaml | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --context "kind-${CLUSTER_NAME}" \
  --from-literal=api-token="${CLOUDFLARE_TOKEN}" \
  --dry-run=client -o yaml \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
echo "  ✓ cloudflare-api-token secret created in cert-manager"

# -- ArgoCD ------------------------------------------------------------------
echo ""
echo "==> Installing ArgoCD ${ARGOCD_VERSION}..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NS" \
  --kube-context "kind-${CLUSTER_NAME}" \
  --version "${ARGOCD_VERSION}" \
  --create-namespace \
  --set configs.params."server\.insecure"=true \
  --wait
echo "  ✓ ArgoCD installed"


export ACME_EMAIL ACME_DOMAIN ACME_WILDCARD ACME_BASE ARGOCD_REPO_URL
envsubst '${ACME_BASE}' \
  < "${MANIFESTS_DIR}/argocd/httproute.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
echo "  ✓ ArgoCD HTTPRoute applied"

# Apply the root app-of-apps — ArgoCD takes over from here
echo ""
echo "==> Applying root app-of-apps..."
ARGOCD_REPO_URL="$ARGOCD_REPO_URL" \
  envsubst '${ARGOCD_REPO_URL}' \
  < "${MANIFESTS_DIR}/argocd/root.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
echo "  ✓ ArgoCD will now sync all infra from ${ARGOCD_REPO_URL}"

# Wait for Envoy Gateway namespace + CRDs (deployed by ArgoCD) then apply
# Gateway and HTTPRoutes with real domain values from user.conf.
echo ""
echo "==> Waiting for Envoy Gateway..."
until kubectl get deployment envoy-gateway \
  --namespace envoy-gateway-system \
  --context "kind-${CLUSTER_NAME}" &>/dev/null; do
  sleep 5
done
kubectl rollout status deployment/envoy-gateway \
  --namespace envoy-gateway-system \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
echo "  ✓ Envoy Gateway ready"
envsubst '${ACME_WILDCARD}' \
  < "${MANIFESTS_DIR}/envoy-gateway/gateway-https.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
envsubst '${ACME_BASE}' \
  < "${MANIFESTS_DIR}/hubble/httproute.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
envsubst '${ACME_BASE}' \
  < "${MANIFESTS_DIR}/monitoring/grafana-httproute.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
echo "  ✓ Gateway + HTTPRoutes applied"

# Wait for cert-manager CRDs (deployed by ArgoCD) then apply
# ClusterIssuer + Certificate with real values from user.conf.
echo ""
echo "==> Waiting for cert-manager CRDs..."
until kubectl get crd clusterissuers.cert-manager.io \
  --context "kind-${CLUSTER_NAME}" &>/dev/null; do
  sleep 5
done
kubectl rollout status deployment/cert-manager-webhook \
  --namespace cert-manager \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=120s
echo "  ✓ cert-manager CRDs ready"
envsubst '${ACME_EMAIL} ${ACME_DOMAIN} ${ACME_WILDCARD} ${ACME_BASE}' \
  < "${MANIFESTS_DIR}/cert-manager/cloudflare-issuer.yaml" \
  | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
echo "  ✓ ClusterIssuer + Certificate applied"

"${SCRIPT_DIR}/argocd-ui.sh" "${CLUSTER_NAME}"

# -- smoke test --------------------------------------------------------------
if [[ "$RUN_TESTS" == true ]]; then
  echo ""
  echo "==> Running Cilium connectivity tests (this takes several minutes)..."
  cilium connectivity test \
    --context "kind-${CLUSTER_NAME}" \
    --hubble=false \
    --test '!pod-to-world' \
    --test '!outside-to-ingress' \
    2>/dev/null || echo "  ! Some connectivity tests skipped (no external access in kind)"
fi

echo ""
echo "Cluster '$CLUSTER_NAME' is bootstrapped."
echo "  kubectl config use-context kind-${CLUSTER_NAME}"
echo ""
echo "  ArgoCD is syncing the following from git:"
echo "    infra/envoy-gateway    — Envoy Gateway controller + config"
echo "    infra/cert-manager     — cert-manager + ClusterIssuer + Certificate"
echo "    infra/monitoring       — Prometheus + Grafana + dashboards"
echo "    infra/hubble           — Hubble UI HTTPRoute"
echo "    infra/workloads        — k8s/apps/ (your app workloads)"
echo ""
echo "  Services (available once ArgoCD syncs, ~2-3 min):"
echo "    https://argocd.${ACME_SUBDOMAIN}.${ACME_DOMAIN}"
echo "    https://grafana.${ACME_SUBDOMAIN}.${ACME_DOMAIN}  (admin/admin)"
echo "    https://hubble.${ACME_SUBDOMAIN}.${ACME_DOMAIN}"
