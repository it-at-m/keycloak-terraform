variable "realm_id" {
  description = "Keycloak Realm ID"
  type        = string
}

variable "client_id" {
  description = "Client ID (OAuth2 client_id)"
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
  description = "Base URL (Default Redirect Path) des Clients"
  type        = string
  default     = ""
}

variable "admin_url" {
  description = "Admin URL des Clients (z.B. fuer Backchannel Logout)"
  type        = string
  default     = ""
}

variable "valid_redirect_uris" {
  description = "Erlaubte Redirect URIs nach dem Login (mind. ein Eintrag erforderlich)"
  type        = list(string)

  validation {
    condition     = length(var.valid_redirect_uris) > 0
    error_message = "Eine Server-Anwendung benoetigt mindestens eine Redirect URI."
  }
}

variable "web_origins" {
  description = "Erlaubte CORS Origins (i.d.R. fuer eine Server-Anwendung leer)"
  type        = list(string)
  default     = []
}

variable "client_secret" {
  description = "Optional: Festes Client Secret. Falls nicht gesetzt, generiert Keycloak ein zufaelliges Secret."
  type        = string
  sensitive   = true
  default     = null
}

variable "default_client_scopes" {
  description = "Default Client Scopes (immer im Token enthalten, unabhaengig vom scope-Parameter). Leere Liste (Default) = Realm-Default-Scopes (keycloak_realm_default_client_scopes, siehe modules/realm-scopes) bleiben unveraendert fuer diesen Client wirksam. Nur explizit setzen, wenn dieser Client von den Realm-Defaults abweichen soll."
  type        = list(string)
  default     = []
}

variable "optional_client_scopes" {
  description = "Optional Client Scopes (muessen vom Client per scope-Parameter angefragt werden)"
  type        = list(string)
  default     = []
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

variable "extra_attributes" {
  description = "Zusaetzliche Client-Attribute (z.B. backchannel.logout.session.required)"
  type        = map(string)
  default     = {}
}

variable "ad_app_identifier" {
  description = "AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen. Wird auf das Client-Attribut \"lhm.ad.app.identifier\" gemappt (siehe modules/oidc-client). null (Default) = Attribut nicht setzen."
  type        = string
  default     = null
}

variable "contact_emails" {
  description = "Ansprechpartner-E-Mail-Adressen fuer die Applikation (komma-separiert im Client-Attribut \"lhm.app.contact.emails\" gespeichert). Ersetzt die Praxis, E-Mails in \"description\" oder \"name\" zu hinterlegen. Leere Liste (Default) = Attribut nicht setzen."
  type        = list(string)
  default     = []
}
