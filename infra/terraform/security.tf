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

# Zone custom-rules entrypoint (one per zone). Rules 1-5 were created in the
# dashboard and imported manually (tofu import); anything not listed here is
# deleted on apply.
resource "cloudflare_ruleset" "waf_custom" {
  zone_id = var.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [
    {
      ref         = "15a3e3189c7e47dbb4fb40c6b372ceec"
      description = "Skip WAF for home_ips"
      expression  = "(ip.src in $home_ips)"
      action      = "skip"
      action_parameters = {
        phases  = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
        ruleset = "current"
      }
      logging = { enabled = true }
    },
    {
      ref         = "70f791dbb11a443297f81683a313fa2e"
      description = "postiz-uploads-bot-exempt"
      expression  = "(starts_with(http.request.uri.path, \"/uploads/\"))"
      action      = "skip"
      action_parameters = {
        phases = ["http_request_sbfm"]
      }
      logging = { enabled = true }
    },
    # Free plan caps custom rules at 5, so extra block conditions go here.
    # Browsers never brotli-encode request bodies; the last clause closes the
    # inbound path to the Node.js Brotli decoder RCE (CVE-2026-111497).
    {
      ref         = "5bae6253cede4e9c9119f8637113ad54"
      description = "Block Common Attacks"
      expression  = "(http.request.uri.path contains \"wp-admin\") or (http.request.uri.path contains \"phpMyAdmin\") or (http.request.uri.path contains \".env\") or (http.request.uri.path contains \".git\") or (http.request.uri.path contains \"wp-content\") or any(lower(http.request.headers[\"content-encoding\"][*])[*] contains \"br\")"
      action      = "block"
    },
    {
      ref         = "10e7c14605bf41e6ad990a9312cc4c6f"
      description = "Challenge High Threats"
      expression  = "(cf.threat_score gt 14)\n"
      action      = "managed_challenge"
    },
    {
      ref         = "731295e2130943bd94a041e05218c75f"
      description = "Block SQL Injection XSS"
      expression  = "(http.request.uri.query contains \"union select\") or\n(http.request.uri.query contains \"<script\") or\n(http.request.uri.query contains \"javascript:\") or\n(http.request.uri.query contains \"' or '1'='1\")"
      action      = "block"
    },
  ]
}

resource "cloudflare_zone_dnssec" "atoca_house" {
  zone_id = var.zone_id
  status  = "active"
}
