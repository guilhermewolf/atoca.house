resource "cloudflare_zero_trust_tunnel_cloudflared" "atoca_house_tunnel" {
  account_id    = var.account_id
  name          = "atoca-house-tunnel"
  config_src    = "cloudflare"
  tunnel_secret = var.cloudflare_tunnel_secret
  lifecycle {
    ignore_changes = [
      tunnel_secret,
    ]
  }
}
