#!/usr/bin/env bash
# Zero-cost runtime proof: build the n8n-runner image, deploy it to a throwaway
# local kind cluster via Helm, prove it runs, test rollback, then tear down.
# Requires: docker, kind, kubectl, helm. No cloud, no cost.
#
# Usage:
#   scripts/local-deploy.sh              # full cycle then delete cluster
#   KEEP=1 scripts/local-deploy.sh       # keep cluster running for manual inspection
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="n8n-runner-local"
RELEASE="n8n"
IMAGE="n8n-runner:local"
DOCKERFILE="$ROOT/n8n-ffmpeg/Dockerfile"
CONTEXT="$ROOT/n8n-ffmpeg"
CHART="$ROOT/charts/n8n-runner"
EVIDENCE="$ROOT/docs/evidence"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found in PATH"; exit 1; }; }
need docker; need kind; need kubectl; need helm

mkdir -p "$EVIDENCE"

cleanup() {
  if [ "${KEEP:-0}" != "1" ]; then
    echo ">>> Tearing down cluster (KEEP=1 to keep it)"
    kind delete cluster --name "$CLUSTER" || true
  else
    echo ">>> KEEP=1 set. Cluster '$CLUSTER' left running."
  fi
}
trap cleanup EXIT

echo ">>> [1/7] Create kind cluster"
kind get clusters | grep -qx "$CLUSTER" || kind create cluster --name "$CLUSTER"

echo ">>> [2/7] Build image"
docker build -t "$IMAGE" -f "$DOCKERFILE" "$CONTEXT"

echo ">>> [3/7] Load image into kind"
kind load docker-image "$IMAGE" --name "$CLUSTER"

echo ">>> [4/7] Helm lint + deploy"
helm lint "$CHART"
helm upgrade --install "$RELEASE" "$CHART" \
  --set image.repository=n8n-runner \
  --set image.tag=local \
  --set image.pullPolicy=Never \
  --wait --timeout 5m

echo ">>> [5/7] Capture running-state evidence"
{
  echo "# local-deploy evidence — $(date -u +%FT%TZ)"
  echo; echo "## kubectl get pods"; kubectl get pods -o wide
  echo; echo "## rollout status"; kubectl rollout status "deploy/${RELEASE}-n8n-runner" --timeout=120s
  echo; echo "## helm list"; helm list
} | tee "$EVIDENCE/local-run.local.txt"

echo ">>> [6/7] Health check via port-forward"
kubectl port-forward "svc/${RELEASE}-n8n-runner" 5678:5678 >/dev/null 2>&1 &
PF_PID=$!
sleep 5
if curl -fsS http://localhost:5678/healthz >>"$EVIDENCE/local-run.local.txt" 2>&1; then
  echo "health OK" | tee -a "$EVIDENCE/local-run.local.txt"
else
  echo "health check FAILED"; kill "$PF_PID" 2>/dev/null || true; exit 1
fi
kill "$PF_PID" 2>/dev/null || true

echo ">>> [7/7] Rollback smoke test"
helm upgrade "$RELEASE" "$CHART" \
  --set image.repository=n8n-runner --set image.tag=local --set image.pullPolicy=Never \
  --set resources.requests.memory=256Mi --wait --timeout 5m
helm rollback "$RELEASE" 1 --wait --timeout 5m
helm history "$RELEASE" | tee -a "$EVIDENCE/local-run.local.txt"

echo ">>> DONE. Evidence: $EVIDENCE/local-run.local.txt"
