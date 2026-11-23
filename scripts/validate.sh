#!/usr/bin/env bash
# Render every kustomize overlay and validate all manifests (Kubernetes + Flux CRDs) with kubeconform.
set -euo pipefail
cd "$(dirname "$0")/.."

out=.tmp/rendered
rm -rf "$out" && mkdir -p "$out"

for dir in infrastructure/lab apps/lab; do
  kubectl kustomize "$dir" > "$out/${dir//\//-}.yaml"
done
find clusters -name '*.yaml' -print0 | while IFS= read -r -d '' f; do
  cp "$f" "$out/$(echo "$f" | tr '/' '-')"
done

summary=$(kubeconform -strict -summary -output text \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  "$out")
echo "$summary"
echo "$summary" | sed -n 's/.*Valid: \([0-9]*\).*/\1/p' > .tmp/valid-count
