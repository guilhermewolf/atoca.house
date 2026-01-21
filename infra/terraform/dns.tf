# Define local variables
locals {
  subdomains = [
    "compartilhado",
    "duplicati",
    "hass",
    "jellyfin",
    "kuma",
    "lidarr",
    "kvm",
    "mass",
    "minio",
    "minio-data",
    "npm",
    "portainer",
    "syncthing",
    "vscode",
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
