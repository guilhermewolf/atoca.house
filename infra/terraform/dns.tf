# Define local variables
locals {
  subdomains = [
    "adguard",
    "anime",
    "autobrr",
    "bazar",
    "compartilhado",
    "duplicati",
    "glances",
    "hass",
    "homebridge",
    "jellyfin",
    "jellyseerr",
    "kuma",
    "lidarr",
    "kvm",
    "mass",
    "minio",
    "minio-data",
    "n8n",
    "nextcloud",
    "npm",
    "portainer",
    "qbittorrent",
    "radar",
    "readar",
    "sabnzbd",
    "slskd",
    "syncthing",
    "sonar",
    "tandoor",
    "vscode",
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