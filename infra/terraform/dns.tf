# Define local variables
locals {
  subdomains = [
    "actual",
    "bazar",
    "comp-netdata",
    "compartilhado",
    "home",
    "jacket",
    "jellyfin",
    "kuma",
    "minio",
    "minio-data",
    "npm",
    "portainer",
    "prowlarr",
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
  value    = var.npm_ip
  type     = "A"
  proxied  = false
}