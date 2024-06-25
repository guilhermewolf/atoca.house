# Cloudflare
variable "cloudflare_api_token" {
  description = "API token for the Cloudflare account"
  type        = string
  default     = ""
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

