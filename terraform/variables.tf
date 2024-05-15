variable "terraform_cloud_token" {
  description = "The API token for Terraform Cloud"
  type        = string
  default     = ""
}


# Cloudflare
variable "cloudflare_api_token" {

  default = ""
}

variable "zone_id" {
  description = "The zone ID for the Cloudflare account"
  type        = string
  default     = ""
}

variable "account_id" {
  description = "The account ID for the Cloudflare account"
  type        = string
  default     = ""
}

variable "domain" {
  description = "The domain name for the Cloudflare account"
  type        = string
  default     = ""
}