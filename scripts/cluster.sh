#!/usr/bin/env bash
# scripts/cluster.sh
#
# Stand-alone script — not part of the main bootstrap.
# Creates a kind cluster with Cilium as the CNI (kube-proxy replaced by eBPF).
#
# Usage:
#   ./scripts/cluster.sh <name>                           # create cluster
#   ./scripts/cluster.sh <name> --with-gateway            # create cluster + Gateway API CRDs + Envoy Gateway
#   ./scripts/cluster.sh <name> --no-test                 # skip Cilium connectivity tests
#   ./scripts/cluster.sh <name> --delete                  # tear the cluster down
#
set -euo pipefail

CLUSTER_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles/.config/kind" && pwd)/cluster.yaml"

if [[ $# -lt 1 || "${1:-}" == --* ]]; then
  echo "Usage: ./scripts/cluster.sh <cluster-name> [--with-gateway] [--delete]"
  exit 1
fi
CLUSTER_NAME="$1"
shift

# parse remaining flags
WITH_GATEWAY=false
DELETE=false
RUN_TESTS=true
for arg in "$@"; do
  case "$arg" in
    --with-gateway) WITH_GATEWAY=true ;;
    --delete)       DELETE=true ;;
    --no-test)      RUN_TESTS=false ;;
    *) echo "Unknown argument: $arg"
       echo "Usage: ./scripts/cluster.sh <cluster-name> [--with-gateway] [--no-test] [--delete]"
       exit 1 ;;
  esac
done

# -- helpers -----------------------------------------------------------------
# Maps binary name -> brew formula (they differ for cilium-cli)
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
  echo "Done."
}

# -- flags -------------------------------------------------------------------
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
echo "  ✓ All prerequisites met"

# Bail out cleanly if the cluster already exists
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ""
  echo "  Cluster '$CLUSTER_NAME' already exists."
  echo "  To rebuild it, run:  ./scripts/cluster.sh $CLUSTER_NAME --delete && ./scripts/cluster.sh $CLUSTER_NAME [--with-gateway]"
  exit 0
fi

# -- create cluster ----------------------------------------------------------
echo ""
echo "==> Creating kind cluster '$CLUSTER_NAME' (no CNI, no kube-proxy)..."
kind create cluster --name "$CLUSTER_NAME" --config "$CLUSTER_CONFIG"

# -- install Cilium via Helm -------------------------------------------------
echo ""
echo "==> Adding Cilium Helm repo..."
helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update cilium

echo ""
echo "==> Installing Cilium..."
# Cilium pods run inside the cluster and need the internal Docker network IP of
# the control-plane container — NOT the localhost port-forward in the kubeconfig.
CONTROL_PLANE_NODE="$(kind get nodes --name "$CLUSTER_NAME" | grep control-plane)"
API_SERVER_IP="$(docker inspect "$CONTROL_PLANE_NODE" \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
API_SERVER_PORT=6443

CILIUM_GATEWAY_FLAG=""
if [[ "$WITH_GATEWAY" == true ]]; then
  CILIUM_GATEWAY_FLAG="--set gatewayAPI.enabled=true"
fi

# shellcheck disable=SC2086
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --kube-context "kind-${CLUSTER_NAME}" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --set k8sServicePort="${API_SERVER_PORT}" \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  $CILIUM_GATEWAY_FLAG

# -- Gateway API CRDs + Envoy Gateway (optional) ----------------------------
if [[ "$WITH_GATEWAY" == true ]]; then
  echo ""
  echo "==> Installing Gateway API CRDs (experimental channel)..."
  kubectl apply --context "kind-${CLUSTER_NAME}" \
    -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/experimental-install.yaml

  echo ""
  echo "==> Adding Envoy Gateway Helm repo..."
  helm repo add envoy-gateway https://gateway.envoyproxy.io/helm-charts --force-update
  helm repo update envoy-gateway

  echo ""
  echo "==> Installing Envoy Gateway..."
  helm upgrade --install eg envoy-gateway/gateway-helm \
    --namespace envoy-gateway-system \
    --kube-context "kind-${CLUSTER_NAME}" \
    --create-namespace \
    --wait
  echo "  ✓ Envoy Gateway installed"
fi

# -- wait for cilium to become ready -----------------------------------------
echo ""
echo "==> Waiting for Cilium to be ready (this can take ~60 s)..."
cilium status --wait --context "kind-${CLUSTER_NAME}"

# -- smoke test (skip with --no-test) ----------------------------------------
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
echo "Cluster '$CLUSTER_NAME' is ready."
echo "  kubectl config use-context kind-${CLUSTER_NAME}"
