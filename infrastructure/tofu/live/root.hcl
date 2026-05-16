# =============================================================================
# infrastructure/tofu/live/root.hcl
#
# Root Terragrunt config for xavifortes.com infrastructure.
#
# State backend creds live in each component's own secrets.sops.json so
# there is no separate common.sops.json required for this repo.
# The child terragrunt.hcl decrypts its own secrets and passes the state
# fields through; root.hcl reads them via inputs or each child can override
# the remote_state block by merging.
#
# Simpler pattern used here: root.hcl defines the remote_state skeleton;
# actual backend credentials are injected by the child via a generate block.
# =============================================================================

locals {
  path_parts = split("/", path_relative_to_include())
  component  = try(local.path_parts[0], "unknown")
}

# ---------------------------------------------------------------------------
# Generate versions_override.tf — cloudflare provider pinned here so child
# modules don't need to repeat it.
# ---------------------------------------------------------------------------
generate "versions" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.7.0"
      required_providers {
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 4.40"
        }
      }
    }
  EOF
}

inputs = {
  component = local.component
}
