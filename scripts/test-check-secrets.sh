#!/usr/bin/env bash
# Tests for check-secrets.sh using a throwaway age key and temporary fixtures.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

expect() { # expect <0|1> <description>
  if "$here/check-secrets.sh" "$tmp/repo" >/dev/null 2>&1; then got=0; else got=1; fi
  if [ "$got" -eq "$1" ]; then pass=$((pass + 1)); echo "ok   - $2"
  else fail=$((fail + 1)); echo "FAIL - $2 (exit $got, expected $1)"; fi
}

age-keygen -o "$tmp/key.txt" 2>/dev/null
recipient=$(age-keygen -y "$tmp/key.txt")
mkdir -p "$tmp/repo/apps"
cat > "$tmp/repo/.sops.yaml" <<YAML
creation_rules:
  - path_regex: .*\.sops\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: $recipient
YAML
secret() { printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: demo\nstringData:\n  password: hunter2\n'; }

expect 0 "repo without secrets passes"

printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: cfg\ndata:\n  kind: Secret\n' > "$tmp/repo/apps/cm.yaml"
expect 0 "ConfigMap mentioning Secret in data passes"

secret > "$tmp/repo/apps/plain.yaml"
expect 1 "plaintext Secret fails"
rm "$tmp/repo/apps/plain.yaml"

secret > "$tmp/repo/apps/demo.sops.yaml"
expect 1 "unencrypted *.sops.yaml fails"

(cd "$tmp/repo" && sops --encrypt --in-place apps/demo.sops.yaml)
expect 0 "SOPS-encrypted Secret passes"

if SOPS_AGE_KEY_FILE="$tmp/key.txt" sops --decrypt "$tmp/repo/apps/demo.sops.yaml" | grep -q 'password: hunter2'; then
  pass=$((pass + 1)); echo "ok   - encrypted Secret decrypts with the age key"
else
  fail=$((fail + 1)); echo "FAIL - encrypted Secret does not decrypt"
fi

if grep -q hunter2 "$tmp/repo/apps/demo.sops.yaml"; then
  fail=$((fail + 1)); echo "FAIL - plaintext value leaked into encrypted file"
else
  pass=$((pass + 1)); echo "ok   - encrypted file contains no plaintext value"
fi

echo "$pass passed, $fail failed"
echo "$pass" > "$here/../.tmp/tests-passed" 2>/dev/null || true
[ "$fail" -eq 0 ]
