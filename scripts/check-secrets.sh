#!/usr/bin/env bash
# Fail if any Kubernetes Secret is committed unencrypted, or a *.sops.yaml file is not SOPS-encrypted.
set -euo pipefail
root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
status=0

# A YAML document is a plaintext Secret when it has a top-level `kind: Secret` (quoted or not) but no
# top-level `sops:` block of its own; checked per document so metadata elsewhere in the file does not count.
has_plaintext_secret() {
  awk -v q="[\"']?" '
    function flush() { if (secret && !sops) bad = 1; secret = sops = 0 }
    /^---/ { flush(); next }
    $0 ~ "^kind:[[:space:]]*" q "Secret" q "[[:space:]]*(#.*)?$" { secret = 1 }
    /^sops:/ { sops = 1 }
    END { flush(); exit !bad }' "$1"
}

while IFS= read -r -d '' f; do
  case "$f" in */.tmp/*|*/.git/*|*/flux-system/*) continue ;; esac
  if has_plaintext_secret "$f"; then
    echo "plaintext Secret: ${f#"$root"/} (encrypt it: sops --encrypt --in-place <file>.sops.yaml)"
    status=1
  fi
  case "$(basename "$f")" in
    .sops.yaml|.sops.yml) ;;
    *.sops.yaml|*.sops.yml)
      if ! grep -Eq '^sops:' "$f" || ! grep -q 'ENC\[' "$f"; then
        echo "not encrypted: ${f#"$root"/}"
        status=1
      fi ;;
  esac
done < <(find "$root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

[ "$status" -eq 0 ] && echo "secrets: all Secrets are SOPS-encrypted"
exit "$status"
