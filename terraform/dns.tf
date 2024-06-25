# Define local variables
locals {
  subdomains = [
    "bazar",
    "cloud",
    "compartilhado",
    "comp-netdata",
    "home",
    "jacket",
    "jellyfin",
    "kuma",
    "npm",
    "portainer",
    "radar",
    "readar",
    "sonar",
    "transmission"
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