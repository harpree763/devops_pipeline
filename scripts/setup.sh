#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 1/8 Checking prerequisites"
for bin in docker kind kubectl helm; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' not found on PATH. Install it and re-run." >&2
    exit 1
  fi
done

echo "==> 2/8 Creating kind cluster 'sdp' (if it doesn't already exist)"
if ! kind get clusters | grep -qx sdp; then
  kind create cluster --config scripts/kind-config.yaml
else
  echo "    kind cluster 'sdp' already exists, skipping"
fi

echo "==> 3/8 Installing Argo Rollouts"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "==> 4/8 Installing ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> 5/8 Installing kube-prometheus-stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/kube-prometheus-stack-values.yaml \
  --wait --timeout 10m

echo "==> 6/8 Installing Loki stack"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  -f monitoring/loki-stack-values.yaml

echo "==> 7/8 Waiting for ArgoCD and Argo Rollouts to be ready, then applying the Application"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argo-rollouts -n argo-rollouts
kubectl apply -f argocd/application.yaml

echo "==> 8/8 Done. Useful commands:"
echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "    kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "    ArgoCD initial admin password:"
echo "      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "    kubectl argo rollouts get rollout demo-service -n demo --watch"
