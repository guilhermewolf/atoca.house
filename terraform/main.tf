terraform {
  backend "pg" {}
}

output "message" {
  value = "Hello, World!2"
}