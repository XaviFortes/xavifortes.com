# =============================================================================
# infrastructure/tofu/live/cloudflare/terragrunt.hcl
#
# Manages all Cloudflare resources for xavifortes.com:
#   - DNS records (A, CNAME, MX, TXT)
#   - SSL/TLS settings (Full Strict)
#   - WAF rules (custom + managed rulesets)
#   - Rate limiting
#
# State backend creds → infrastructure/tofu/live/common.sops.json (this repo)
# Cloudflare secrets  → secrets.sops.json (this directory)
#
# To create secrets from scratch:
#   ./scripts/bootstrap-secrets.sh
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common  = jsondecode(sops_decrypt_file(find_in_parent_folders("common.sops.json")))
  secrets = jsondecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.sops.json"))
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  disable_init = true

  config = {
    bucket     = local.common.state_bucket_name
    access_key = local.common.state_access_key
    secret_key = local.common.state_secret_key

    key    = "xavifortes/cloudflare/tofu.tfstate"
    region = "us-west-004"

    endpoint                    = startswith(local.common.state_endpoint, "http") ? local.common.state_endpoint : "https://${local.common.state_endpoint}"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true

    skip_bucket_root_access    = true
    skip_bucket_enforced_tls   = true
    skip_requesting_account_id = true
    use_lockfile               = false
  }
}

terraform {
  source = "../../modules//cloudflare"
}

inputs = {
  cloudflare_api_token = local.secrets.cloudflare_api_token
  zone_id              = local.secrets.cloudflare_zone_id
  gra8_ipv4            = local.secrets.gra8_public_ipv4
}
