#!/usr/bin/env bash
# Install the local git hooks.  Hooks are not version controlled, so this has to
# be run once per clone:   ./scripts/install-hooks.sh
set -euo pipefail

cd "$(dirname "$0")/.."
HOOKS=$(git rev-parse --git-path hooks)
mkdir -p "$HOOKS"

cat > "$HOOKS/pre-push" <<'EOF'
#!/usr/bin/env bash
exec "$(git rev-parse --show-toplevel)/scripts/pre-push-scan.sh" "$@"
EOF
chmod +x "$HOOKS/pre-push" scripts/pre-push-scan.sh

echo "installed: $HOOKS/pre-push -> scripts/pre-push-scan.sh"
echo "bypass once with: git push --no-verify"
