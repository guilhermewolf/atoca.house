resource "cloudflare_r2_bucket" "rpi_k8s" {
  account_id     = var.account_id
  name           = "rpi-k8s-backup"
  jurisdiction   = "default"
  location       = "WEUR"
  storage_class  = "Standard"
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [
      jurisdiction,
      location,
      storage_class
    ]
  }
}

resource "cloudflare_r2_bucket" "rpi_k8s_crunchy_postgres" {
  account_id     = var.account_id
  name           = "rpi-k8s-crunchy-postgres"
  jurisdiction   = "default"
  location       = "WEUR"
  storage_class  = "Standard"
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [
      jurisdiction,
      location,
      storage_class
    ]
  }
}
