#!/usr/bin/env bash
# Install pinned CLI tools for CI (linux/amd64) into ~/bin: scripts/install-tools.sh <tool>...
# Tools: kubeconform sops age k3d kube-linter gitleaks. Uses `gh release download` (needs GH_TOKEN).
set -euo pipefail
KUBECONFORM_VERSION=v0.8.0
SOPS_VERSION=v3.13.3
AGE_VERSION=v1.3.2
K3D_VERSION=v5.9.0
KUBE_LINTER_VERSION=v0.8.3
GITLEAKS_VERSION=v8.30.1

bin="$HOME/bin"
mkdir -p "$bin"
[ -n "${GITHUB_PATH:-}" ] && echo "$bin" >> "$GITHUB_PATH"

fetch() { gh release download "$2" -R "$1" -p "$3" -O "${4:--}"; }

for tool in "$@"; do
  case "$tool" in
    kubeconform) fetch yannh/kubeconform "$KUBECONFORM_VERSION" kubeconform-linux-amd64.tar.gz | tar xz -C "$bin" kubeconform ;;
    sops) fetch getsops/sops "$SOPS_VERSION" "sops-$SOPS_VERSION.linux.amd64" "$bin/sops" ;;
    age) fetch FiloSottile/age "$AGE_VERSION" "age-$AGE_VERSION-linux-amd64.tar.gz" \
           | tar xz --strip-components=1 -C "$bin" age/age age/age-keygen ;;
    k3d) fetch k3d-io/k3d "$K3D_VERSION" k3d-linux-amd64 "$bin/k3d" ;;
    kube-linter) fetch stackrox/kube-linter "$KUBE_LINTER_VERSION" kube-linter-linux.tar.gz | tar xz -C "$bin" kube-linter ;;
    gitleaks) fetch gitleaks/gitleaks "$GITLEAKS_VERSION" "gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" | tar xz -C "$bin" gitleaks ;;
    *) echo "unknown tool: $tool" >&2; exit 1 ;;
  esac
  chmod +x "$bin/$tool" 2>/dev/null || true
  echo "installed $tool"
done
chmod +x "$bin"/*
