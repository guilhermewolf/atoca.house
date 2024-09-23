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
  sensitive   = true
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

variable "npm_ip" {
  description = "The IP address for the NPM"
  type        = string
  default     = ""
  sensitive   = true
}

