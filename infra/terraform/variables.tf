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

variable "cloudflare_tunnel_secret" {
  description = "The tunnel secret for the Cloudflare Zero Trust Tunnel"
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

variable "unifi_api_url" {
  description = "The API URL for the Unifi controller"
  type        = string
  default     = ""
}

variable "unifi_api_key" {
  description = "The API key for the Unifi controller"
  type        = string
  default     = ""
  sensitive   = true
}
