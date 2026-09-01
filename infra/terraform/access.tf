
resource "cloudflare_zero_trust_access_service_token" "kf_events" {
  account_id = var.account_id
  name       = "kf-events-worker"
  duration   = "8760h"
}

resource "cloudflare_zero_trust_access_application" "n8n_webhooks" {
  account_id = var.account_id
  name       = "n8n webhooks (hooks.atoca.house)"
  type       = "self_hosted"
  domain     = "hooks.atoca.house"

  destinations = [{
    type = "public"
    uri  = "hooks.atoca.house"
  }]

  app_launcher_visible      = false
  auto_redirect_to_identity = false

  policies = [{
    name       = "kf-events worker only"
    decision   = "non_identity"
    precedence = 1
    include = [{
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.kf_events.id
      }
    }]
  }]
}
