# =============================================================================
# OIDC Client Template: Server-Anwendung mit User-Login
#
# Szenario gemaess "Client-Typen" in docs/oidc-integration.md
# (Repo https://git.muenchen.de/directory-services/idp):
#   Authorization Code Flow | Confidential Client | mit Client Secret
#
# Folgende sicherheitsrelevanten Einstellungen sind bewusst NICHT als Variable
# exponiert, sondern fest verdrahtet - sie koennen bei der Anlage ueber dieses
# Template also nicht vergessen oder versehentlich falsch gesetzt werden:
#   - Confidential Client (client_authenticator_type = "client-secret")
#   - Nur Authorization Code Flow aktiv (Implicit/Direct Grants/Service Account aus)
#   - Full Scope Allowed = false
#
# Fuer Sonderfaelle, die von diesem Standard abweichen muessen (z.B. zusaetzlich
# Client Credentials Flow auf demselben Client), direkt modules/oidc-client
# verwenden.
# =============================================================================

module "oidc_client" {
  source = "../oidc-client"

  realm_id    = var.realm_id
  client_id   = var.client_id
  name        = var.name
  description = var.description
  enabled     = var.enabled

  client_authenticator_type    = "client-secret"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
  full_scope_allowed           = false

  client_secret = var.client_secret

  root_url            = var.root_url
  base_url            = var.base_url
  admin_url           = var.admin_url
  valid_redirect_uris = var.valid_redirect_uris
  web_origins         = var.web_origins

  default_client_scopes  = var.default_client_scopes
  optional_client_scopes = var.optional_client_scopes

  roles = var.roles

  extra_attributes  = var.extra_attributes
  ad_app_identifier = var.ad_app_identifier
  contact_emails    = var.contact_emails
}
