# =============================================================================
# DNS Records
# =============================================================================

# Apex A record → GRA8 HAProxy
resource "cloudflare_record" "apex" {
  zone_id         = var.zone_id
  name            = "@"
  type            = "A"
  content         = var.gra8_ipv4
  proxied         = true # Traffic through Cloudflare WAF
  ttl             = 1    # Auto (proxied records ignore TTL)
  allow_overwrite = true # Take ownership of pre-existing apex A record
}

# www CNAME → apex
resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  type    = "CNAME"
  content = "xavifortes.com"
  proxied = true
  ttl     = 1
}

# =============================================================================
# SSL/TLS Settings
# Full Strict: Cloudflare <-> Origin encrypted, cert must be valid
# =============================================================================

resource "cloudflare_zone_settings_override" "xavifortes" {
  zone_id = var.zone_id

  settings {
    # TLS
    ssl                      = "strict"
    min_tls_version          = "1.2"
    tls_1_3                  = "zrt"
    automatic_https_rewrites = "on"
    always_use_https         = "on"

    # Performance
    brotli      = "on"
    http3       = "on"
    zero_rtt    = "on"
    early_hints = "on"

    # Security
    security_level           = "medium"
    browser_check            = "on"
    hotlink_protection       = "off"
    email_obfuscation        = "on"
    server_side_exclude      = "on"
    opportunistic_encryption = "on"

    # Caching
    cache_level       = "aggressive"
    browser_cache_ttl = 14400

    challenge_ttl = 1800
  }
}

# =============================================================================
# WAF — Custom Rules (Free plan compatible)
#
# Removed:
#   - `matches` operator  → requires Business plan
#   - cf.bot_management.* → requires Bot Management add-on
#
# Free plan supports: contains, eq, in, starts_with, ends_with, ip.src,
#   http.user_agent, http.request.uri.path, ip.geoip.country
# =============================================================================

resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = var.zone_id
  name        = "xavifortes custom WAF rules"
  description = "Custom WAF rules for xavifortes.com"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  # Block requests with no User-Agent header at all
  # (http.user_agent == "" catches the empty string; Free-compatible)
  rules {
    action      = "block"
    description = "Block empty User-Agent"
    expression  = "(http.user_agent eq \"\")"
    enabled     = true
  }

  # Block known scanners and bad bots by UA substring
  rules {
    action      = "block"
    description = "Block known vulnerability scanners and bad bots"
    expression  = <<-EOT
      (http.user_agent contains "sqlmap") or
      (http.user_agent contains "nikto") or
      (http.user_agent contains "masscan") or
      (http.user_agent contains "zgrab") or
      (http.user_agent contains "nmap") or
      (http.user_agent contains "nuclei") or
      (http.user_agent contains "python-requests" and not http.request.uri.path contains "/api")
    EOT
    enabled     = true
  }

  # Block path traversal attempts
  rules {
    action      = "block"
    description = "Block path traversal attempts"
    expression  = "(http.request.uri.path contains \"../\") or (http.request.uri.path contains \"..%2f\") or (http.request.uri.path contains \"%2e%2e%2f\")"
    enabled     = true
  }

  # Geo-challenge without bot_management field (Free-compatible)
  # Uses managed_challenge so Cloudflare decides JS vs CAPTCHA
  rules {
    action      = "managed_challenge"
    description = "Challenge high-risk countries"
    expression  = "ip.geoip.country in {\"CN\" \"RU\" \"KP\" \"IR\"}"
    enabled     = false # Enable when you're happy with the other rules first
  }
}

# =============================================================================
# Rate Limiting (Free plan compatible)
#
# Free plan constraints:
#   - period must be 10 (only allowed value on Free)
#   - requests_per_period minimum is 1
# =============================================================================

resource "cloudflare_ruleset" "rate_limit" {
  zone_id     = var.zone_id
  name        = "xavifortes rate limiting"
  description = "Rate limit rules for xavifortes.com"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    action      = "block"
    description = "Rate limit aggressive crawlers — 20 req/10s per IP"
    expression  = "true"
    enabled     = true

    action_parameters {
      response {
        status_code  = 429
        content_type = "application/json"
        content      = "{\"error\": \"rate limited\"}"
      }
    }

    ratelimit {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10 # Free plan: only 10s windows allowed
      requests_per_period = 20
      mitigation_timeout  = 10 # Free plan: only 10s allowed
    }
  }
}

# =============================================================================
# www → apex redirect
#
# http_request_dynamic_redirect (Transform Rules) requires Pro plan — not
# available on Free. cloudflare_page_rule rejects API tokens (error 1011).
#
# www redirect is handled at Traefik level via IngressRoute middleware.
# The www CNAME proxies through CF → GRA8 → Traefik which issues the 301.
# No Cloudflare-side redirect resource needed.
# =============================================================================
