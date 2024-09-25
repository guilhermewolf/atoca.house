# Define local variables
locals {
  subdomains = [
    "actual",
    "bazar",
    "compartilhado",
    "jellyfin",
    "kuma",
    "minio",
    "minio-data",
    "npm",
    "portainer",
    "readar",
    "sabnzbd",
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