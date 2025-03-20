# Define local variables
locals {
  subdomains = [
    "adguard",
    "bazar",
    "compartilhado",
    "hass",
    "jellyfin",
    "jellyseerr",
    "kuma",
    "kvm",
    "minio",
    "minio-data",
    "n8n",
    "npm",
    "portainer",
    "radar",
    "readar",
    "sabnzbd",
    "sonar",
    "tandoor",
    "transmission",
    "wyl"
  ]
  domain = "atoca.house"
}

# Create DNS records for each subdomain
resource "cloudflare_dns_record" "subdomain" {
  for_each = toset(local.subdomains)
  zone_id  = var.zone_id
  name     = "${each.value}.${local.domain}"
  content  = var.npm_ip
  type     = "A"
  ttl      = 1
  proxied  = false
}