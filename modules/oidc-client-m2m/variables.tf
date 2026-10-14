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

variable "client_secret" {
  description = "Optional: Festes Client Secret. Falls nicht gesetzt, generiert Keycloak ein zufaelliges Secret."
  type        = string
  sensitive   = true
  default     = null
}

variable "default_client_scopes" {
  description = "Default Client Scopes (immer im Token enthalten, unabhaengig vom scope-Parameter)"
  type        = list(string)
  default     = []
}

variable "optional_client_scopes" {
  description = "Optional Client Scopes (muessen vom Client per scope-Parameter angefragt werden)"
  type        = list(string)
  default     = []
}

variable "roles" {
  description = "Client Roles inkl. optionaler Composite-Rollen, die dieser Client anderen Service-Accounts zur Verfuegung stellt (Format siehe modules/oidc-client)"
  type = map(object({
    description = optional(string, "")
    composite_roles = optional(list(object({
      role      = string
      client_id = optional(string, null) # null = Realm-Role, "self" = gleicher Client, sonst Client-UUID
    })), [])
  }))
  default = {}
}

variable "service_account_roles" {
  description = "Client-Rollen anderer Clients, die dem Service-Account dieses M2M-Clients zugewiesen werden (z.B. { client_id = \"realm-management\", role = \"manage-users\" })"
  type = list(object({
    client_id = string # Client ID (nicht UUID) des Ziel-Clients, dessen Rolle zugewiesen wird
    role      = string # Name der Rolle auf dem Ziel-Client
  }))
  default = []
}

variable "extra_attributes" {
  description = "Zusaetzliche Client-Attribute"
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
