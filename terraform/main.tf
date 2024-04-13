terraform {
  cloud {
    organization = "atoca-house"

    workspaces {
      name = "atoca-house"
    }
  }
}
output "test" {
  value = "test"
}

