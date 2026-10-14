# =============================================================================
# SAML Client Template: Assertion signiert + Client Signature Required
#
# Szenario gemaess "Signatur- und Verschluesselungs-Konfiguration" in
# docs/saml-integration.md (Repo https://git.muenchen.de/directory-services/idp):
#   Response (Dokument) signiert | Assertion signiert
#   | Client Signature Required (SP signiert AuthnRequest/LogoutRequest)
#   | keine Assertion-Verschluesselung
#
# Folgende sicherheitsrelevanten Einstellungen sind bewusst NICHT als Variable
# exponiert, sondern fest verdrahtet - sie koennen bei der Anlage ueber dieses
# Template also nicht vergessen oder versehentlich falsch gesetzt werden:
#   - sign_documents  = true (Response signiert)
#   - sign_assertions = true (Assertion signiert, IDP-seitig Pflicht)
#   - client_signature_required = true (signierte Requests vom SP erforderlich)
#   - encrypt_assertions = false (keine Assertion-Verschluesselung)
#   - signature_algorithm = RSA_SHA256
#   - full_scope_allowed = false
#
# signing_certificate (oeffentliches SP-Zertifikat) ist Pflicht, damit
# Keycloak die vom SP signierten AuthnRequests/LogoutRequests pruefen kann.
#
# Fuer Sonderfaelle (z.B. ohne Client-Signatur oder mit Verschluesselung),
# eines der anderen Templates (saml-client-signed, saml-client-encrypted)
# oder modules/saml-client direkt verwenden.
# =============================================================================

module "saml_client" {
  source = "../saml-client"

  realm_id    = var.realm_id
  client_id   = var.client_id
  name        = var.name
  description = var.description
  enabled     = var.enabled

  include_authn_statement   = true
  sign_documents            = true
  sign_assertions           = true
  client_signature_required = true
  encrypt_assertions        = false
  signature_algorithm       = "RSA_SHA256"
  full_scope_allowed        = false

  signing_certificate = var.signing_certificate

  name_id_format       = var.name_id_format
  force_name_id_format = var.force_name_id_format

  force_post_binding   = var.force_post_binding
  front_channel_logout = var.front_channel_logout

  root_url            = var.root_url
  base_url            = var.base_url
  valid_redirect_uris = var.valid_redirect_uris

  assertion_consumer_post_url         = var.assertion_consumer_post_url
  assertion_consumer_redirect_url     = var.assertion_consumer_redirect_url
  logout_service_post_binding_url     = var.logout_service_post_binding_url
  logout_service_redirect_binding_url = var.logout_service_redirect_binding_url

  idp_initiated_sso_url_name    = var.idp_initiated_sso_url_name
  idp_initiated_sso_relay_state = var.idp_initiated_sso_relay_state

  roles                  = var.roles
  saml_attribute_mappers = var.saml_attribute_mappers

  extra_attributes  = var.extra_attributes
  ad_app_identifier = var.ad_app_identifier
  contact_emails    = var.contact_emails
}
