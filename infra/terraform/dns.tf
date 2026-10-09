# Define local variables
locals {
  subdomains = [
    "compartilhado",
    "duplicati",
    "hass",
    "kuma",
    "kvm",
    "mass",
    "npm",
    "portainer",
    "syncthing",
    "vscode",
  ]
  domain = "atoca.house"
}

# Create DNS records for each subdomain
resource "unifi_dns_record" "subdomain" {
  for_each    = toset(local.subdomains)
  name        = "${each.value}.${local.domain}"
  enabled     = true
  record_type = "A"
  ttl         = "5m"
  value       = var.npm_ip
}

# No AAAA on proxied records. UniFi only holds A records for *.atoca.house, so
# AAAA lookups fall through to Cloudflare and IPv6-preferring clients (e.g. the
# Tailscale browser extension) skip the LAN gateway and fail. IPv4-only keeps
# tailnet/LAN clients on the local gateway.
resource "cloudflare_zone_setting" "ipv6" {
  zone_id    = var.zone_id
  setting_id = "ipv6"
  value      = "off"
}
