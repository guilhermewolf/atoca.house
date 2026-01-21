resource "cloudflare_r2_bucket" "atoca_house_cluster_backup" {
  account_id     = var.account_id
  name           = "atoca-house-cluster-backup"
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

resource "cloudflare_r2_bucket" "atoca_house_crunchy_postgres" {
  account_id     = var.account_id
  name           = "atoca-house-crunchy-postgres"
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
