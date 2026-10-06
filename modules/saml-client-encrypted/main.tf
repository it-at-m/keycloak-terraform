# =============================================================================
# SAML Client Template: Assertion signiert + Client Signature Required
#                        + Encrypt Assertions
#
# Szenario gemaess "Signatur- und Verschluesselungs-Konfiguration" in
# docs/saml-integration.md (Repo https://git.muenchen.de/directory-services/idp):
#   Response (Dokument) signiert | Assertion signiert
#   | Client Signature Required (SP signiert AuthnRequest/LogoutRequest)
#   | Assertion verschluesselt mit dem oeffentlichen Schluessel des SP
#
# Folgende sicherheitsrelevanten Einstellungen sind bewusst NICHT als Variable
# exponiert, sondern fest verdrahtet - sie koennen bei der Anlage ueber dieses
# Template also nicht vergessen oder versehentlich falsch gesetzt werden:
#   - sign_documents  = true (Response signiert)
#   - sign_assertions = true (Assertion signiert, IDP-seitig Pflicht)
#   - client_signature_required = true (signierte Requests vom SP erforderlich)
#   - encrypt_assertions = true (Assertion-Verschluesselung)
#   - signature_algorithm = RSA_SHA256
#   - full_scope_allowed = false
#
# signing_certificate und encryption_certificate (oeffentliche SP-Zertifikate)
# sind Pflicht. Gemaess docs/saml-integration.md ist eine Verschluesselung der
# Assertion insbesondere dann sinnvoll, wenn zusaetzlich eine Autorisierung
# anhand von Rollen (Attribut "Role") konfiguriert wird, z.B. bei SaaS-/Cloud-
# Anwendungen ausserhalb des LHM-Netzes.
#
# Fuer Sonderfaelle (z.B. ohne Verschluesselung), eines der anderen Templates
# (saml-client-signed, saml-client-signed-requests) oder modules/saml-client
# direkt verwenden.
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
  encrypt_assertions        = true
  signature_algorithm       = "RSA_SHA256"
  full_scope_allowed        = false

  signing_certificate    = var.signing_certificate
  encryption_certificate = var.encryption_certificate

  encryption_algorithm                = var.encryption_algorithm
  encryption_key_algorithm            = var.encryption_key_algorithm
  encryption_digest_method            = var.encryption_digest_method
  encryption_mask_generation_function = var.encryption_mask_generation_function

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
