terraform {
  backend "pg" {}
}

resource "cloudflare_record" "test" {
  zone_id = var.zone_id
  name    = "test"
  value   = "192.168.1.1"
  type    = "CNAME"
  proxied = true
}