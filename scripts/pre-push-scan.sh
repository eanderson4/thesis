#!/usr/bin/env bash
# Scan commits about to be pushed for credentials and personal information.
#
# Installed as a pre-push hook by scripts/install-hooks.sh.  Zero dependencies
# beyond git and grep, so there is nothing to keep up to date.
#
# BLOCK  - high-confidence secrets (recognisable key formats).  Push is refused.
# WARN   - things that are often fine in a thesis (emails, phone numbers) but
#          worth a look before they go to a public repo.  Push continues.
#
# Bypass a single push with:  git push --no-verify
# Permanently allow a match:  add a regex line to .secretsignore
set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ROOT=$(git rev-parse --show-toplevel)
IGNORE="$ROOT/.secretsignore"

# --- what counts as a secret ------------------------------------------------
# Deliberately format-based, not entropy-based: far fewer false positives, and
# it catches the tokens that actually get leaked.
BLOCK_PATTERNS=(
  'gh[pousr]_[A-Za-z0-9]{36,}'                       # GitHub PAT (classic)
  'github_pat_[A-Za-z0-9_]{60,}'                     # GitHub PAT (fine-grained)
  'AKIA[0-9A-Z]{16}'                                 # AWS access key id
  'ASIA[0-9A-Z]{16}'                                 # AWS temporary key id
  'sk-[A-Za-z0-9]{32,}'                              # OpenAI / generic secret key
  'sk-ant-[A-Za-z0-9_-]{20,}'                        # Anthropic API key
  'xox[baprs]-[A-Za-z0-9-]{10,}'                     # Slack token
  'AIza[0-9A-Za-z_-]{35}'                            # Google API key
  '[rs]k_live_[0-9a-zA-Z]{24,}'                      # Stripe live key
  'glpat-[A-Za-z0-9_-]{20,}'                         # GitLab PAT
  'BEGIN [A-Z ]*PRIVATE KEY'                         # PEM private key
  'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'   # JWT
  '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[=:][[:space:]]*["'"'"'][^"'"'"']{8,}'
)
WARN_PATTERNS=(
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'   # email address
  '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b'                   # US SSN
  '\b(\+1[ -]?)?\(?[0-9]{3}\)?[ -][0-9]{3}-[0-9]{4}\b'  # US phone
  '\b[0-9]{1,5} [A-Z][a-z]+ (Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Dr)\b'
)

filter_ignored() {
  [ -f "$IGNORE" ] || { cat; return; }
  grep -vEf <(grep -vE '^\s*(#|$)' "$IGNORE") || true
}

scan() {  # scan <label> <colour> <patterns...>  -> prints hits, returns 1 if any
  local label=$1 colour=$2; shift 2
  local pat hits found=0
  for pat in "$@"; do
    hits=$(printf '%s\n' "$DIFF" | grep -nE "$pat" 2>/dev/null | filter_ignored | head -5)
    [ -z "$hits" ] && continue
    found=1
    printf '%s%s%s  %s\n' "$colour" "$label" "$OFF" "$pat"
    printf '%s      %s%s\n' "$DIM" "$(printf '%s' "$hits" | head -3 | cut -c1-160 | tr '\n' '\n')" "$OFF"
  done
  return $((1 - found))
}

# --- collect the diff being pushed ------------------------------------------
ZERO='0000000000000000000000000000000000000000'
EMPTY_TREE=$(git hash-object -t tree /dev/null)   # 4b825dc6... for sha1 repos
RANGES=()
while read -r _local_ref local_sha _remote_ref remote_sha; do
  [ -z "${local_sha:-}" ] && continue
  [ "$local_sha" = "$ZERO" ] && continue                      # branch deletion
  if [ "$remote_sha" != "$ZERO" ] && git rev-parse -q --verify "$remote_sha^{commit}" >/dev/null; then
    RANGES+=("$remote_sha $local_sha")
  else
    # New branch (or unknown remote tip): scan every commit not already on a
    # remote, falling back to the empty tree when the branch has no parent.
    first=$(git rev-list --max-count=200 "$local_sha" --not --remotes 2>/dev/null | tail -1)
    if [ -n "$first" ] && git rev-parse -q --verify "$first^{commit}" >/dev/null 2>&1 \
       && git rev-parse -q --verify "$first^" >/dev/null 2>&1; then
      RANGES+=("$first^ $local_sha")
    else
      RANGES+=("$EMPTY_TREE $local_sha")
    fi
  fi
done

[ ${#RANGES[@]} -eq 0 ] && exit 0

DIFF=""
for r in "${RANGES[@]}"; do
  set -- $r
  DIFF+=$(git diff "$1" "$2" 2>/dev/null | grep '^+' | grep -v '^+++' || true)
  DIFF+=$'\n'
done
[ -z "$(printf '%s' "$DIFF" | tr -d '[:space:]')" ] && exit 0

# --- report ------------------------------------------------------------------
echo "pre-push: scanning $(printf '%s\n' "$DIFF" | wc -l) added lines"

WARNED=0
scan "WARN " "$YEL" "${WARN_PATTERNS[@]}" && WARNED=1

if scan "BLOCK" "$RED" "${BLOCK_PATTERNS[@]}"; then
  echo
  echo "${RED}Push refused: possible credential in the commits above.${OFF}"
  echo "  Not a secret?  add the pattern to .secretsignore"
  echo "  Override once: git push --no-verify"
  echo "  Already committed?  rotate the credential first, rewriting history does not un-leak it."
  exit 1
fi

if [ "$WARNED" = 1 ]; then
  echo "${YEL}Warnings only - push continues.${OFF}  Repo is public; confirm the above is intended."
else
  echo "${GRN}pre-push: clean.${OFF}"
fi
exit 0
