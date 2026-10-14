# =============================================================================
# OIDC Client Template: Dienst-zu-Dienst (M2M)
#
# Szenario gemaess "Client-Typen" in docs/oidc-integration.md
# (Repo https://git.muenchen.de/directory-services/idp):
#   Client Credentials Flow | Confidential Client | mit Client Secret
#
# Folgende sicherheitsrelevanten Einstellungen sind bewusst NICHT als Variable
# exponiert, sondern fest verdrahtet - sie koennen bei der Anlage ueber dieses
# Template also nicht vergessen oder versehentlich falsch gesetzt werden:
#   - Confidential Client (client_authenticator_type = "client-secret")
#   - Nur Client Credentials Flow aktiv (kein User-Login, kein Redirect)
#   - Full Scope Allowed = false
#
# Fuer Sonderfaelle, die von diesem Standard abweichen muessen, direkt
# modules/oidc-client verwenden.
# =============================================================================

terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

module "oidc_client" {
  source = "../oidc-client"

  realm_id    = var.realm_id
  client_id   = var.client_id
  name        = var.name
  description = var.description
  enabled     = var.enabled

  client_authenticator_type    = "client-secret"
  standard_flow_enabled        = false
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = true
  full_scope_allowed           = false

  client_secret = var.client_secret

  # Kein User-Login -> kein Redirect / keine CORS-Origins noetig
  valid_redirect_uris = []
  web_origins         = []

  default_client_scopes  = var.default_client_scopes
  optional_client_scopes = var.optional_client_scopes

  roles = var.roles

  extra_attributes  = var.extra_attributes
  ad_app_identifier = var.ad_app_identifier
  contact_emails    = var.contact_emails
}

# =============================================================================
# Service Account Rollen auf anderen Clients zuweisen
# (z.B. realm-management.manage-users fuer einen IAM-Sync-Client)
# =============================================================================

data "keycloak_openid_client" "service_account_role_clients" {
  for_each = toset([for r in var.service_account_roles : r.client_id])

  realm_id  = var.realm_id
  client_id = each.value
}

resource "keycloak_openid_client_service_account_role" "service_account_roles" {
  for_each = {
    for r in var.service_account_roles : "${r.client_id}.${r.role}" => r
  }

  realm_id                = var.realm_id
  service_account_user_id = module.oidc_client.service_account_user_id

  client_id = data.keycloak_openid_client.service_account_role_clients[each.value.client_id].id
  role      = each.value.role
}
