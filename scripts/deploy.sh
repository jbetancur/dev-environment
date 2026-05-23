#!/usr/bin/env bash
# scripts/deploy.sh
#
# Build a Docker image, push it to the local kind registry, and roll out
# the updated deployment in the cluster.
#
# Usage:
#   ./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>
#
# Example:
#   ./scripts/deploy.sh myapp ./services/myapp myapp myapp
#
set -euo pipefail

REGISTRY="localhost:5001"

if [[ $# -ne 4 ]]; then
  echo "Usage: ./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>"
  echo "Example: ./scripts/deploy.sh myapp ./services/myapp myapp myapp"
  exit 1
fi

IMAGE="$1"
CONTEXT="$2"
NAMESPACE="$3"
DEPLOYMENT="$4"
TAG="${REGISTRY}/${IMAGE}:latest"

echo "==> Building ${TAG}..."
docker build -t "$TAG" "$CONTEXT"

echo "==> Pushing ${TAG} to local registry..."
docker push "$TAG"

echo "==> Rolling out ${NAMESPACE}/${DEPLOYMENT}..."
kubectl rollout restart deployment/"$DEPLOYMENT" --namespace "$NAMESPACE"
kubectl rollout status deployment/"$DEPLOYMENT" --namespace "$NAMESPACE" --timeout=120s

echo ""
echo "Done. ${DEPLOYMENT} is running the latest image."
