# Postgres Backend
variable "db_hostname" {
  description = "The hostname of the PostgreSQL database"
  type        = string
}

variable "db_name" {
  description = "The name of the PostgreSQL database"
  type        = string
}

variable "db_user" {
  description = "The username for the PostgreSQL database"
  type        = string
}

variable "db_password" {
  description = "The password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

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

