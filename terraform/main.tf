terraform {
  cloud {
    organization = "atoca-house"

    workspaces {
      name = "atoca-house"
    }
  }
}

#create a output message saying test
output "message" {
  value = "Hello, World!"
}

