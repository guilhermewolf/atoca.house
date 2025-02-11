resource "cloudflare_r2_bucket" "rpi_k8s" {
  account_id = var.account_id
  name       = "rpi-k8s-backup"
  location   = "WEUR"
}

resource "cloudflare_r2_bucket" "rpi_k8s_crunchy_postgres" {
  account_id = var.account_id
  name       = "rpi-k8s-crunchy-postgres"
  location   = "WEUR"
}