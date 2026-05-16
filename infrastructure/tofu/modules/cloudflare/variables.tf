variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Edit and DNS:Edit permissions."
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for xavifortes.com."
  type        = string
  sensitive   = true
}

variable "gra8_ipv4" {
  description = "Public IPv4 address of the OVH GRA8 HAProxy VPS."
  type        = string
  sensitive   = true
}
