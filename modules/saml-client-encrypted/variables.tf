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
  description = "Erlaubte Redirect-/Assertion-Consumer-Service-URIs (mind. ein Eintrag erforderlich)"
  type        = list(string)

  validation {
    condition     = length(var.valid_redirect_uris) > 0
    error_message = "Ein SAML-Client benoetigt mindestens eine Assertion Consumer Service (ACS) URL."
  }
}

variable "assertion_consumer_post_url" {
  description = "Assertion Consumer Service URL fuer POST Binding (optional, falls abweichend von valid_redirect_uris)"
  type        = string
  default     = null
}

variable "assertion_consumer_redirect_url" {
  description = "Assertion Consumer Service URL fuer Redirect Binding (optional)"
  type        = string
  default     = null
}

variable "logout_service_post_binding_url" {
  description = "Single Logout Service URL fuer POST Binding (optional)"
  type        = string
  default     = null
}

variable "logout_service_redirect_binding_url" {
  description = "Single Logout Service URL fuer Redirect Binding (optional)"
  type        = string
  default     = null
}

variable "name_id_format" {
  description = "Format des NameID-Elements (username, email, transient, persistent). Empfehlung gemaess docs/saml-integration.md: persistent."
  type        = string
  default     = "persistent"
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

variable "signing_certificate" {
  description = "Oeffentliches Zertifikat (PEM, ohne Header/Footer) des SP zur Pruefung signierter AuthnRequests/LogoutRequests. Pflicht, da client_signature_required = true."
  type        = string
}

variable "encryption_certificate" {
  description = "Oeffentliches Zertifikat (PEM, ohne Header/Footer) des SP zur Verschluesselung der Assertion. Pflicht, da encrypt_assertions = true."
  type        = string
}

variable "encryption_algorithm" {
  description = "Symmetrischer Algorithmus zur Assertion-Verschluesselung (z.B. AES_128_GCM, AES_256_GCM). Default: Provider-Default."
  type        = string
  default     = null
}

variable "encryption_key_algorithm" {
  description = "Algorithmus zur Verschluesselung des symmetrischen Schluessels (RSA-OAEP-11, RSA-OAEP-MGF1P, RSA1_5). Default: Provider-Default (RSA-OAEP-11)."
  type        = string
  default     = null
}

variable "encryption_digest_method" {
  description = "Digest-Methode fuer die Schluesselverschluesselung (SHA-1, SHA-256, SHA-512). Default: Provider-Default (SHA-256)."
  type        = string
  default     = null
}

variable "encryption_mask_generation_function" {
  description = "Mask Generation Function fuer RSA-OAEP (mgf1sha1, mgf1sha224, mgf1sha256, mgf1sha384, mgf1sha512). Default: Provider-Default (mgf1sha256)."
  type        = string
  default     = null
}

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

variable "saml_attribute_mappers" {
  description = "User Attribute Mapper - bilden Keycloak User-Attribute auf SAML-Attribute im AttributeStatement ab (z.B. lhmObjectID, Role)"
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
  description = "AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen. Wird auf das Client-Attribut \"lhm.ad.app.identifier\" gemappt (siehe modules/saml-client). null (Default) = Attribut nicht setzen."
  type        = string
  default     = null
}

variable "contact_emails" {
  description = "Ansprechpartner-E-Mail-Adressen fuer die Applikation (komma-separiert im Client-Attribut \"lhm.app.contact.emails\" gespeichert). Ersetzt die Praxis, E-Mails in \"description\" oder \"name\" zu hinterlegen. Leere Liste (Default) = Attribut nicht setzen."
  type        = list(string)
  default     = []
}
