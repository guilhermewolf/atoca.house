# Define local variables
locals {
  subdomains = [
    "actual",
    "bazar",
    "compartilhado",
    "jellyfin",
    "jellyseerr",
    "kuma",
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
resource "cloudflare_record" "subdomain" {
  for_each = toset(local.subdomains)
  zone_id  = var.zone_id
  name     = "${each.value}.${local.domain}"
  content  = var.npm_ip
  type     = "A"
  proxied  = false
}