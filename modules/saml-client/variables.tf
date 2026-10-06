variable "realm_id" {
  description = "Keycloak Realm ID"
  type        = string
}

variable "client_id" {
  description = "SAML Entity ID des Clients (Service Provider)"
  type        = string
}

variable "name" {
  description = "Anzeigename des Clients"
  type        = string
}

variable "description" {
  description = "Client-Beschreibung"
  type        = string
  default     = ""
}

variable "enabled" {
  description = "Client aktiviert"
  type        = bool
  default     = true
}

# =============================================================================
# SAML Processing
# =============================================================================

variable "include_authn_statement" {
  description = "AuthnStatement in die SAML-Response aufnehmen"
  type        = bool
  default     = true
}

variable "sign_documents" {
  description = "SAML-Dokumente (Response) mit dem Realm-Schluessel signieren"
  type        = bool
  default     = true
}

variable "sign_assertions" {
  description = "Assertion innerhalb der SAML-Response signieren"
  type        = bool
  default     = false
}

variable "encrypt_assertions" {
  description = "Assertion mit dem oeffentlichen Schluessel des Clients verschluesseln"
  type        = bool
  default     = false
}

variable "client_signature_required" {
  description = "Vom Client (SP) signierte Dokumente (AuthnRequest/LogoutRequest) erwarten"
  type        = bool
  default     = true
}

variable "signature_algorithm" {
  description = "Signaturalgorithmus (RSA_SHA1, RSA_SHA256, RSA_SHA256_MGF1, RSA_SHA512, RSA_SHA512_MGF1, DSA_SHA1)"
  type        = string
  default     = null
}

variable "signature_key_name" {
  description = "Wie der Signatur-Schluessel in der KeyInfo referenziert wird (NONE, KEY_ID, CERT_SUBJECT)"
  type        = string
  default     = null
}

variable "canonicalization_method" {
  description = "XML-Kanonisierungsmethode (EXCLUSIVE, EXCLUSIVE_WITH_COMMENTS, INCLUSIVE, INCLUSIVE_WITH_COMMENTS)"
  type        = string
  default     = null
}

variable "name_id_format" {
  description = "Format des NameID-Elements (username, email, transient, persistent)"
  type        = string
  default     = null
}

variable "force_name_id_format" {
  description = "Vom SP angefragtes NameID-Format ignorieren und immer name_id_format verwenden"
  type        = bool
  default     = false
}

variable "force_post_binding" {
  description = "SAML POST Binding statt Redirect Binding erzwingen"
  type        = bool
  default     = true
}

variable "front_channel_logout" {
  description = "Front-Channel Logout (ueber den Browser) statt Back-Channel Logout verwenden"
  type        = bool
  default     = true
}

# =============================================================================
# URLs
# =============================================================================

variable "root_url" {
  description = "Root URL des Clients"
  type        = string
  default     = ""
}

variable "base_url" {
  description = "Base URL (Default Endpoint) des Clients"
  type        = string
  default     = ""
}

variable "valid_redirect_uris" {
  description = "Erlaubte Redirect-/Assertion-Consumer-Service-URIs"
  type        = list(string)
  default     = []
}

variable "master_saml_processing_url" {
  description = "Single Endpoint URL fuer alle SAML-Requests/-Responses (ACS, SLO, IdP-initiated)"
  type        = string
  default     = null
}

variable "assertion_consumer_post_url" {
  description = "Assertion Consumer Service URL fuer POST Binding"
  type        = string
  default     = null
}

variable "assertion_consumer_redirect_url" {
  description = "Assertion Consumer Service URL fuer Redirect Binding"
  type        = string
  default     = null
}

variable "logout_service_post_binding_url" {
  description = "Single Logout Service URL fuer POST Binding"
  type        = string
  default     = null
}

variable "logout_service_redirect_binding_url" {
  description = "Single Logout Service URL fuer Redirect Binding"
  type        = string
  default     = null
}

variable "idp_initiated_sso_url_name" {
  description = "URL-Alias fuer IdP-initiated SSO (.../realms/{realm}/protocol/saml/clients/{alias})"
  type        = string
  default     = null
}

variable "idp_initiated_sso_relay_state" {
  description = "Relay State fuer IdP-initiated SSO"
  type        = string
  default     = null
}

# =============================================================================
# Zertifikate (Service Provider)
# =============================================================================

variable "signing_certificate" {
  description = "Oeffentliches Zertifikat (PEM, ohne Header/Footer) des SP zur Pruefung signierter AuthnRequests/LogoutRequests. Erforderlich, wenn client_signature_required = true."
  type        = string
  default     = null
}

variable "encryption_certificate" {
  description = "Oeffentliches Zertifikat (PEM, ohne Header/Footer) des SP zur Verschluesselung der Assertion. Erforderlich, wenn encrypt_assertions = true."
  type        = string
  default     = null
}

variable "encryption_algorithm" {
  description = "Symmetrischer Algorithmus zur Assertion-Verschluesselung (z.B. AES_128_GCM, AES_256_GCM)"
  type        = string
  default     = null
}

variable "encryption_key_algorithm" {
  description = "Algorithmus zur Verschluesselung des symmetrischen Schluessels (RSA-OAEP-11, RSA-OAEP-MGF1P, RSA1_5)"
  type        = string
  default     = null
}

variable "encryption_digest_method" {
  description = "Digest-Methode fuer die Schluesselverschluesselung (SHA-1, SHA-256, SHA-512)"
  type        = string
  default     = null
}

variable "encryption_mask_generation_function" {
  description = "Mask Generation Function fuer RSA-OAEP (mgf1sha1, mgf1sha224, mgf1sha256, mgf1sha384, mgf1sha512)"
  type        = string
  default     = null
}

# =============================================================================
# Consent & Scope
# =============================================================================

variable "full_scope_allowed" {
  description = "Alle Realm-/Client-Rollen automatisch in die Assertion aufnehmen"
  type        = bool
  default     = true
}

variable "consent_required" {
  description = "User-Consent vor erstem Login erforderlich"
  type        = bool
  default     = false
}

# =============================================================================
# Rollen
# =============================================================================

variable "roles" {
  description = "Client Roles inkl. optionaler Composite-Rollen (Format siehe modules/oidc-client)"
  type = map(object({
    description = optional(string, "")
    composite_roles = optional(list(object({
      role      = string
      client_id = optional(string, null) # null = Realm-Role, "self" = gleicher Client, sonst Client-UUID
    })), [])
  }))
  default = {}
}

# =============================================================================
# Attribute Mapping
# =============================================================================

variable "saml_attribute_mappers" {
  description = "User Attribute Mapper - bilden Keycloak User-Attribute auf SAML-Attribute im AttributeStatement ab"
  type = map(object({
    user_attribute             = string
    saml_attribute_name        = string
    saml_attribute_name_format = optional(string, "Basic") # Unspecified | Basic | URI Reference
    friendly_name              = optional(string, "")
    aggregate_attributes       = optional(bool, false)
  }))
  default = {}
}

variable "extra_attributes" {
  description = "Zusaetzliche Client-Attribute (extra_config)"
  type        = map(string)
  default     = {}
}

variable "ad_app_identifier" {
  description = "AD-App-Bezeichner fuer die AD-Provisionierung (Ableitung der Applikations-OU OU=<id>,OU=Applikationen,... und der AD-Gruppen lhm-ab-<id>-<rolle>). Entkoppelt diese technische Bindung vom Anzeigenamen (name)/client_id. Wird auf das Client-Attribut \"lhm.ad.app.identifier\" gemappt. null (Default) = Attribut nicht setzen (AD-Seite faellt dann auf ClientName/ClientID zurueck)."
  type        = string
  default     = null
}

variable "contact_emails" {
  description = "Ansprechpartner-E-Mail-Adressen fuer die Applikation (komma-separiert im Client-Attribut \"lhm.app.contact.emails\" gespeichert). Ersetzt die Praxis, E-Mails in \"description\" oder \"name\" zu hinterlegen. Leere Liste (Default) = Attribut nicht setzen."
  type        = list(string)
  default     = []
}
