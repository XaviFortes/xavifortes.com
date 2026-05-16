output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = var.zone_id
  sensitive   = true
}

output "apex_record_id" {
  description = "Cloudflare DNS record ID for the apex A record"
  value       = cloudflare_record.apex.id
}

output "www_record_id" {
  description = "Cloudflare DNS record ID for the www CNAME"
  value       = cloudflare_record.www.id
}
