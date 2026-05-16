#!/usr/bin/env bash
# =============================================================================
# scripts/bootstrap-secrets.sh
#
# Interactive helper to create and SOPS-encrypt all secret files from their
# .json.tpl templates. Run this once when setting up the repo for the first time.
#
# Requirements:
#   - sops  (brew install sops)
#   - age   (brew install age)
#   - jq    (brew install jq)
#
# Your Age private key must be in ~/.config/sops/age/keys.txt, OR
# the SOPS_AGE_KEY environment variable must be set.
# The public keys are already defined in .sops.yaml.
#
# Usage:
#   chmod +x scripts/bootstrap-secrets.sh
#   ./scripts/bootstrap-secrets.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Check dependencies
for cmd in sops age jq; do
  command -v "$cmd" &>/dev/null || error "'$cmd' is not installed. Run: brew install $cmd"
done

# Check Age key is available
if [[ -z "${SOPS_AGE_KEY:-}" ]] && [[ ! -f "${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" ]]; then
  error "No Age private key found. Either:
  - Set SOPS_AGE_KEY environment variable, OR
  - Place your key in ~/.config/sops/age/keys.txt
  Generate a new key with: age-keygen -o ~/.config/sops/age/keys.txt"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "============================================================"
echo "  xavifortes.com — secrets bootstrap"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Helper: prompt user to fill in a template and produce an encrypted file
# ---------------------------------------------------------------------------
process_template() {
  local tpl_path="$1"
  local out_path="${tpl_path%.json.tpl}.sops.json"
  local description="$2"

  echo ""
  info "Processing: ${description}"
  info "Template:   ${tpl_path#$REPO_ROOT/}"
  info "Output:     ${out_path#$REPO_ROOT/}"

  local work_file="${tpl_path%.tpl}"

  if [[ -f "$out_path" ]]; then
    warn "Encrypted file already exists: ${out_path#$REPO_ROOT/}"
    read -rp "  Do you want to edit it? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Skipping."; return; }
    
    info "Decrypting existing file..."
    sops --decrypt "$out_path" > "$work_file"
    
    # Merge any missing keys from the template (template combined with the existing decrypted structure)
    jq -s '.[0] * .[1]' "$tpl_path" "$work_file" > "${work_file}.tmp" && mv "${work_file}.tmp" "$work_file"
  else
    # Copy template to working file (first time)
    cp "$tpl_path" "$work_file"
  fi

  # Read each key and prompt for value
  echo ""
  echo "  Fill/Review values. Press Enter to keep current value."
  echo ""

  local keys
  keys=$(jq -r 'keys[]' "$work_file")

  if [[ -n "$keys" ]]; then
    while IFS= read -r key <&3; do
      local current
      current=$(jq -r --arg k "$key" '.[$k]' "$work_file")
      echo -e "  ${YELLOW}${key}${NC}"
      echo    "  Current/Description: ${current}"
      read -rp "  New Value: " value
      if [[ -n "$value" ]]; then
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$work_file" > "${work_file}.tmp" \
          && mv "${work_file}.tmp" "$work_file"
      fi
      echo ""
    done 3<<< "$keys"
  fi

  # Give option to manually edit (e.g., adding/removing completely custom fields)
  read -rp "  Do you want to manually edit the JSON file to add/remove fields via your editor? [y/N] " manual_edit
  if [[ "$manual_edit" =~ ^[Yy]$ ]]; then
    ${EDITOR:-nano} "$work_file"
    echo ""
  fi

  # Verify no FILL_IN placeholders remain
  if grep -q "FILL_IN" "$work_file"; then
    warn "Some values are still unfilled:"
    grep "FILL_IN" "$work_file"
    echo ""
    read -rp "  Encrypt anyway (you can fix and re-run)? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      rm -f "$work_file"
      info "Aborted. Edit ${tpl_path#$REPO_ROOT/} manually and re-run."
      return
    fi
  fi

  # Encrypt with SOPS
  info "Encrypting with SOPS..."
  sops --encrypt "$work_file" > "$out_path"

  # Clean up plaintext working file
  rm -f "$work_file"

  success "Encrypted: ${out_path#$REPO_ROOT/}"
}

# ---------------------------------------------------------------------------
# Process each template
# ---------------------------------------------------------------------------

process_template \
  "${REPO_ROOT}/infrastructure/tofu/live/common.json.tpl" \
  "B2 state backend credentials (shared across all components)"

process_template \
  "${REPO_ROOT}/infrastructure/tofu/live/cloudflare/secrets.json.tpl" \
  "Cloudflare token, zone ID, GRA8 IP"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
success "Bootstrap complete!"
echo ""
info "Next steps:"
echo "  1. Verify encrypted files were created:"
echo "     ls infrastructure/tofu/live/common.sops.json"
echo "     ls infrastructure/tofu/live/cloudflare/secrets.sops.json"
echo ""
echo "  2. Run Terraform:"
echo "     cd infrastructure/tofu/live/cloudflare"
echo "     terragrunt plan"
echo ""
echo "  3. Add these as GitHub Actions secrets:"
echo "     SOPS_AGE_KEY  → value of the AGE-SECRET-KEY-... line from keys.txt"
echo "     (GITHUB_TOKEN is auto-provided)"
echo "============================================================"
echo ""
echo "============================================================"
success "Bootstrap complete!"
echo ""
info "Next steps:"
echo "  1. Verify encrypted files were created:"
echo "     ls infrastructure/tofu/live/common.sops.json"
echo "     ls infrastructure/tofu/live/cloudflare/secrets.sops.json"
echo ""
echo "  2. Run Terraform:"
echo "     cd infrastructure/tofu/live/cloudflare"
echo "     terragrunt plan"
echo ""
echo "  3. Add SOPS_AGE_KEY as a GitHub Actions secret:"
echo "     cat ~/.config/sops/age/keys.txt | grep AGE-SECRET-KEY"
echo "     # Add that value to GitHub → Settings → Secrets → SOPS_AGE_KEY"
echo ""
echo "  4. The CI pipeline also needs GITHUB_TOKEN (auto-provided)."
echo "============================================================"
echo ""
