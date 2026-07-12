terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.21.1"
    }
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.55.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "unifi" {
  api_url        = var.unifi_api_url
  api_key        = var.unifi_api_key
  allow_insecure = true
}
