#!/usr/bin/env bash
# End-to-end test: create the k3d lab cluster, deploy the repo and check podinfo answers through the ingress.
#   MODE=flux (default): install Flux and reconcile this repo from GitHub at GIT_BRANCH / GIT_SHA.
#   MODE=kustomize:      apply the overlays directly (no GitHub access needed).
set -euo pipefail
cd "$(dirname "$0")/.."

MODE=${MODE:-flux}
CLUSTER=${CLUSTER:-lab}
REPO_URL=${REPO_URL:-https://github.com/Hawuawu/K8S-Homelab}
GIT_BRANCH=${GIT_BRANCH:-main}
GIT_SHA=${GIT_SHA:-}
mkdir -p .tmp

dump() {
  echo "::group::diagnostics"
  flux get all -A 2>/dev/null || true
  kubectl get pods -A -o wide || true
  kubectl get events -A --sort-by=.lastTimestamp | tail -40 || true
  echo "::endgroup::"
}
trap 'dump' ERR

if ! k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  k3d cluster create --config bootstrap/k3d-lab.yaml
fi
kubectl wait --for=condition=Ready nodes --all --timeout=120s
for _ in $(seq 60); do kubectl -n kube-system get deployment traefik >/dev/null 2>&1 && break; sleep 3; done
kubectl -n kube-system rollout status deployment/traefik --timeout=3m

if [ "$MODE" = flux ]; then
  flux install --components=source-controller,kustomize-controller
  age-keygen -o .tmp/e2e.agekey 2>/dev/null
  kubectl -n flux-system create secret generic sops-age \
    --from-file=age.agekey=.tmp/e2e.agekey --dry-run=client -o yaml | kubectl apply -f -
  rm -f .tmp/e2e.agekey
  flux create source git flux-system --url="$REPO_URL" --branch="$GIT_BRANCH" \
    ${GIT_SHA:+--commit="$GIT_SHA"} --interval=1m
  kubectl apply -f clusters/lab/infrastructure.yaml -f clusters/lab/apps.yaml
  kubectl -n flux-system wait kustomization/infrastructure kustomization/apps \
    --for=condition=Ready --timeout=5m
else
  kubectl apply -k infrastructure/lab
  kubectl apply -k apps/lab
fi

kubectl -n podinfo rollout status deployment/podinfo --timeout=3m
curl -fsS --retry 30 --retry-all-errors --retry-delay 2 \
  --resolve podinfo.localhost:8080:127.0.0.1 http://podinfo.localhost:8080/ | tee .tmp/podinfo.json
grep -q 'Deployed by Flux from GitHub' .tmp/podinfo.json
echo
echo "e2e ($MODE): podinfo is served at http://podinfo.localhost:8080"
