#!/usr/bin/env bash
# pulumi/setup.sh
#
# Reads pulumi/.env and configures your Pulumi stack.
# Copy pulumi/.env.example to pulumi/.env, fill in your values, then run this.
#
# Usage:
#   cp pulumi/.env.example pulumi/.env
#   # edit pulumi/.env
#   ./pulumi/setup.sh
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -f .env ]]; then
  echo "Error: pulumi/.env not found."
  echo "  cp pulumi/.env.example pulumi/.env"
  echo "  # edit .env with your values, then re-run"
  exit 1
fi

source .env

: "${STACK?}"
: "${DOMAIN?}"
: "${SUBDOMAIN?}"
: "${EMAIL?}"
: "${REPO_URL?}"
CERT_MODE="${CERT_MODE:-letsencrypt}"
ARGOCD_VERSION="${ARGOCD_VERSION:-9.5.15}"
ENVOY_GATEWAY_VERSION="${ENVOY_GATEWAY_VERSION:-v1.8.0}"
CILIUM_VERSION="${CILIUM_VERSION:-1.19.4}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.20.2}"
KUBE_PROMETHEUS_STACK_VERSION="${KUBE_PROMETHEUS_STACK_VERSION:-85.3.0}"
LOKI_VERSION="${LOKI_VERSION:-7.0.0}"
PROMTAIL_VERSION="${PROMTAIL_VERSION:-6.17.1}"

pulumi login --local
pulumi stack init "$STACK" 2>/dev/null || pulumi stack select "$STACK"

pulumi config set clusterName "$STACK"
pulumi config set domain      "$DOMAIN"
pulumi config set subdomain   "$SUBDOMAIN"
pulumi config set email       "$EMAIL"
pulumi config set repoUrl     "$REPO_URL"
pulumi config set certMode                   "$CERT_MODE"
pulumi config set argoCdVersion              "$ARGOCD_VERSION"
pulumi config set envoyGatewayVersion        "$ENVOY_GATEWAY_VERSION"
pulumi config set ciliumVersion              "$CILIUM_VERSION"
pulumi config set certManagerVersion         "$CERT_MANAGER_VERSION"
pulumi config set kubePrometheusStackVersion "$KUBE_PROMETHEUS_STACK_VERSION"
pulumi config set lokiVersion                "$LOKI_VERSION"
pulumi config set promtailVersion            "$PROMTAIL_VERSION"

if [[ "$CERT_MODE" == "letsencrypt" ]]; then
  : "${CF_TOKEN?CF_TOKEN is required when CERT_MODE=letsencrypt}"
  pulumi config set --secret cloudflareToken "$CF_TOKEN"
fi

echo ""
echo "Stack '$STACK' configured. Run 'pulumi up' to bootstrap the cluster."
