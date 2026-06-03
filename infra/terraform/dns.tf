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
  ttl         = 300
  value       = var.npm_ip
}
