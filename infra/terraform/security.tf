# Baseline security response headers for every proxied hostname.
# Each header is only added when the origin did not already send it,
# so apps with stricter values (e.g. Authelia) keep their own.
resource "cloudflare_ruleset" "security_headers" {
  zone_id     = var.zone_id
  name        = "Security headers"
  description = "Baseline security headers when the origin omits them"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules = [
    {
      description = "X-Content-Type-Options"
      expression  = "not any(lower(http.response.headers.names[*])[*] == \"x-content-type-options\")"
      action      = "rewrite"
      action_parameters = {
        headers = {
          "X-Content-Type-Options" = { operation = "set", value = "nosniff" }
        }
      }
    },
    {
      description = "X-Frame-Options"
      expression  = "not any(lower(http.response.headers.names[*])[*] == \"x-frame-options\")"
      action      = "rewrite"
      action_parameters = {
        headers = {
          "X-Frame-Options" = { operation = "set", value = "SAMEORIGIN" }
        }
      }
    },
    {
      description = "Referrer-Policy"
      expression  = "not any(lower(http.response.headers.names[*])[*] == \"referrer-policy\")"
      action      = "rewrite"
      action_parameters = {
        headers = {
          "Referrer-Policy" = { operation = "set", value = "strict-origin-when-cross-origin" }
        }
      }
    },
    {
      description = "Permissions-Policy"
      expression  = "not any(lower(http.response.headers.names[*])[*] == \"permissions-policy\")"
      action      = "rewrite"
      action_parameters = {
        headers = {
          "Permissions-Policy" = { operation = "set", value = "camera=(), microphone=(), geolocation=(), payment=(), usb=()" }
        }
      }
    },
    {
      description = "Strip framework fingerprint"
      expression  = "true"
      action      = "rewrite"
      action_parameters = {
        headers = {
          "X-Powered-By" = { operation = "remove" }
        }
      }
    },
  ]
}

resource "cloudflare_zone_dnssec" "atoca_house" {
  zone_id = var.zone_id
  status  = "active"
}
