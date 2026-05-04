#!/usr/bin/env bash
# scripts/cluster.sh
#
# Stand-alone script — not part of the main bootstrap.
# Creates a kind cluster with Cilium as the CNI (kube-proxy replaced by eBPF).
#
# Usage:
#   ./scripts/cluster.sh <name>                           # create cluster
#   ./scripts/cluster.sh <name> --with-gateway            # + Gateway API CRDs + Envoy Gateway
#   ./scripts/cluster.sh <name> --with-certs              # + cert-manager
#   ./scripts/cluster.sh <name> --no-test                 # skip Cilium connectivity tests
#   ./scripts/cluster.sh <name> --delete                  # tear the cluster down
#
set -euo pipefail

CLUSTER_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles/.config/kind" && pwd)/cluster.yaml"
MANIFESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../k8s" && pwd)"

# -- versions & release names ------------------------------------------------
# EG_VERSION pins both the gateway-crds and gateway-helm charts — they ship
# together so the CRDs are always compatible with the controller.
# https://github.com/envoyproxy/gateway/releases
EG_VERSION="v1.7.2"
CILIUM_RELEASE="cilium"
CILIUM_NS="kube-system"
EG_RELEASE="eg"
EG_NS="envoy-gateway-system"
# https://github.com/cert-manager/cert-manager/releases
CERT_MANAGER_VERSION="v1.17.2"
# Local registry — the container name becomes its hostname inside the kind network
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

if [[ $# -lt 1 || "${1:-}" == --* ]]; then
  echo "Usage: ./scripts/cluster.sh <cluster-name> [--with-gateway] [--delete]"
  exit 1
fi
CLUSTER_NAME="$1"
shift

# parse remaining flags
WITH_GATEWAY=false
WITH_CERTS=false
DELETE=false
RUN_TESTS=true
for arg in "$@"; do
  case "$arg" in
    --with-gateway) WITH_GATEWAY=true ;;
    --with-certs)   WITH_CERTS=true ;;
    --delete)       DELETE=true ;;
    --no-test)      RUN_TESTS=false ;;
    *) echo "Unknown argument: $arg"
       echo "Usage: ./scripts/cluster.sh <cluster-name> [--with-gateway] [--with-certs] [--no-test] [--delete]"
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
  # Remove the local registry only if no other kind clusters are using it
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

# Connect the registry container into the kind network so nodes can reach it
# by the hostname "kind-registry" (as configured in containerdConfigPatches).
docker network connect "kind" "$REGISTRY_NAME" 2>/dev/null || true

# Write hosts.toml into every node so containerd resolves localhost:5001 -> kind-registry:5000
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
  cat <<EOF | docker exec -i "$node" tee "/etc/containerd/certs.d/localhost:${REGISTRY_PORT}/hosts.toml" > /dev/null
[host."http://${REGISTRY_NAME}:5000"]
EOF
done

# Publish registry info for tools like Tilt/Skaffold
kubectl apply --context "kind-${CLUSTER_NAME}" \
  -f "${MANIFESTS_DIR}/registry/local-registry-hosting.yaml"
echo "  ✓ Registry wired — push to localhost:${REGISTRY_PORT}/myimage, pull as localhost:${REGISTRY_PORT}/myimage"

# -- Gateway API CRDs (installed before Cilium so the operator finds them on startup)
if [[ "$WITH_GATEWAY" == true ]]; then
  echo ""
  echo "==> Installing Gateway API + Envoy Gateway CRDs (${EG_VERSION})..."
  helm template gateway-crds oci://docker.io/envoyproxy/gateway-crds-helm \
    --kube-context "kind-${CLUSTER_NAME}" \
    --version "${EG_VERSION}" \
    --set crds.gatewayAPI.enabled=true \
    --set crds.gatewayAPI.channel=experimental \
    --set crds.envoyGateway.enabled=true \
    | kubectl apply --server-side -f - --context "kind-${CLUSTER_NAME}"
  echo "  ✓ Gateway API CRDs installed"
fi

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
helm upgrade --install "$CILIUM_RELEASE" cilium/cilium \
  --namespace "$CILIUM_NS" \
  --kube-context "kind-${CLUSTER_NAME}" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --set k8sServicePort="${API_SERVER_PORT}" \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  $CILIUM_GATEWAY_FLAG

# Wait for Cilium to be fully ready before installing anything else —
# until Cilium agents are up, worker nodes have node.cilium.io/agent-not-ready:NoSchedule
# which prevents any other pods (including EG certgen) from scheduling.
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
# kind does not ship metrics-server; without it kubectl top and HPA don't work.
echo ""
echo "==> Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --kube-context "kind-${CLUSTER_NAME}" \
  --set args={--kubelet-insecure-tls}
echo "  ✓ metrics-server installed"

# -- Envoy Gateway controller (optional) ------------------------------------
if [[ "$WITH_GATEWAY" == true ]]; then
  echo ""
  echo "==> Installing Envoy Gateway ${EG_VERSION}..."
  helm upgrade --install "$EG_RELEASE" oci://docker.io/envoyproxy/gateway-helm \
    --namespace "$EG_NS" \
    --kube-context "kind-${CLUSTER_NAME}" \
    --version "${EG_VERSION}" \
    --create-namespace \
    --skip-crds \
    --wait
  echo "  ✓ Envoy Gateway installed"

  echo ""
  echo "==> Configuring Envoy proxy + GatewayClass for kind..."
  kubectl apply --context "kind-${CLUSTER_NAME}" \
    -f "${MANIFESTS_DIR}/envoy-gateway/envoy-proxy-kind.yaml"
  kubectl apply --context "kind-${CLUSTER_NAME}" \
    -f "${MANIFESTS_DIR}/envoy-gateway/gatewayclass.yaml"
  echo "  ✓ EnvoyProxy + GatewayClass 'eg' configured"

  # Apply the shared Gateway that handles all inbound traffic on 80 (and 443
  # when --with-certs provides the TLS secret).  Use the https variant only
  # when cert-manager will also be installed; fall back to http-only otherwise.
  echo ""
  echo "==> Creating shared Gateway 'local'..."
  if [[ "$WITH_CERTS" == true ]]; then
    kubectl apply --context "kind-${CLUSTER_NAME}" \
      -f "${MANIFESTS_DIR}/envoy-gateway/gateway-https.yaml"
  else
    kubectl apply --context "kind-${CLUSTER_NAME}" \
      -f "${MANIFESTS_DIR}/envoy-gateway/gateway.yaml"
  fi
  echo "  ✓ Gateway 'local' created in ${EG_NS}"
fi

# -- cert-manager (optional) -------------------------------------------------
if [[ "$WITH_CERTS" == true ]]; then
  echo ""
  echo "==> Installing cert-manager ${CERT_MANAGER_VERSION}..."
  helm repo add jetstack https://charts.jetstack.io --force-update
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --kube-context "kind-${CLUSTER_NAME}" \
    --version "${CERT_MANAGER_VERSION}" \
    --create-namespace \
    --set crds.enabled=true \
    --wait
  echo "  ✓ cert-manager installed"

  echo ""
  echo "==> Applying local CA and localhost TLS certificate..."
  kubectl apply --context "kind-${CLUSTER_NAME}" \
    -f "${MANIFESTS_DIR}/cert-manager/local-ca.yaml"
  # Wait for the local-tls secret to be created by cert-manager before continuing
  echo "  Waiting for 'local-tls' secret in ${EG_NS}..."
  kubectl wait certificate local-tls \
    --namespace "$EG_NS" \
    --context "kind-${CLUSTER_NAME}" \
    --for=condition=Ready \
    --timeout=120s
  echo "  ✓ local-tls certificate ready — https://localhost available"
fi

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
