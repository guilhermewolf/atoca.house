terraform {
  backend "pg" {}
}

output "test" {
  value = "test"
}

# module "cloudflare" {
#   source = "./cloudflare"
#   zone_id = "123"
#   zone_name = "example.com"
#   records = [
#       {
#         name = "test",
#         type = "A",
#         value = "
#       }
#   ]
# }

module "argocd" {
  source = "./argocd"
}

provider "argocd" {
  server_addr = "argocd.atoca.house"
}