variable "optional_scopes" {
  description = "List of optional client scopes (custom scopes only - 'roles' is added automatically based on skip_default_scopes_lookup)"
  type        = list(string)
  default = [
    "LHM",
    "LHM_Extended"
  ]
}


variable "realm_id" {
  description = "Realm IDs"
  type        = list(string)
  default     = []
}

variable "realm_blacklist" {
  description = "Realms to exclude from scope management"
  type        = list(string)
  default     = []
}

variable "bootstrap_realm_ids" {
  description = <<-EOT
    Realms, die im SELBEN Apply erst noch von Terraform angelegt werden
    (eigene keycloak_realm-Ressource im Environment) und daher in Keycloak
    noch nicht existieren. Fuer diese Realms werden nur die Lookups/
    Ressourcen uebersprungen, die bereits existierende Keycloak-Objekte
    voraussetzen wuerden (Data-Source-Lookups der Built-in-Scopes,
    roles-Scope + client-roles-Mapper, phone-Mapper). Alles rein neu
    Erstellbare (lhm-core, LHM, LHM_Extended inkl. Mapper, lhm-core-saml,
    Default-/Optional-Scope-Zuordnung) wird sofort im selben Apply angelegt.

    Empfohlenes Muster im Environment - settled sich von selbst, sobald
    run_terraform.py den Realm discovered hat (kein zweiter Commit noetig,
    der uebersprungene Rest kommt dann per Discovery + Import dazu):

      locals {
        new_realms = [keycloak_realm.mein_realm.realm]
      }

      module "realm_scopes" {
        # ...
        realm_id            = distinct(concat(var.realm_id, local.new_realms))
        bootstrap_realm_ids = [for r in local.new_realms : r if !contains(var.realm_id, r)]
      }
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.bootstrap_realm_ids : contains(var.realm_id, r)])
    error_message = "Jeder Realm in bootstrap_realm_ids muss auch in realm_id enthalten sein."
  }
}

variable "bootstrap_realm_refs" {
  description = <<-EOT
    Map Realm-Name -> Realm-ID als RESSOURCEN-REFERENZ (z.B. "ts-predev" =
    keycloak_realm.ts_predev.id) fuer Realms, die im selben Apply erst
    angelegt werden. Erzeugt die noetige Apply-Reihenfolge (Realm VOR den
    Scopes) - ohne diese Referenz racen die Scope-Creates gegen die
    Realm-Erstellung und schlagen mit "404 Realm not found" fehl (real
    passiert beim ersten ts-predev-Apply).

    Bewusst als Map-VALUE (nicht in for_each/realm_id-Listen): die
    for_each-Keys bleiben literale Strings, nur die realm_id-Werte der
    Bootstrap-Instanzen werden zur (beim ersten Plan unbekannten)
    Ressourcen-Referenz. Fuer alle anderen Realms liefert lookup() den
    unveraenderten Namen -> kein Plan-Diff (siehe Befund B9 in
    docs/architecture/realm-modules-review.md, warum die Referenz NICHT in
    realm_id/bootstrap_realm_ids stehen darf).

    Der Eintrag kann nach dem Settling dauerhaft stehen bleiben
    (keycloak_realm.X.id ist dann aus dem State bekannt und identisch mit
    dem Realm-Namen -> weiterhin kein Diff).
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.bootstrap_realm_refs) : contains(var.realm_id, k)])
    error_message = "Jeder Key in bootstrap_realm_refs muss auch in realm_id enthalten sein."
  }
}

# Environment-specific attribute mappings for environments without LDAP
variable "attribute_mappings" {
  description = "Override attribute mappings for environments without LDAP (e.g., local, dev)"
  type = object({
    ldap_entry_dn = optional(string, "LDAP_ENTRY_DN")
    # Weitere Attribute können hier hinzugefügt werden
  })
  default = {
    ldap_entry_dn = "LDAP_ENTRY_DN"
  }
}

variable "manage_roles_scope" {
  description = "Whether to manage the roles scope as a resource (false = use data source for existing scope)"
  type        = bool
  default     = true
}

variable "skip_default_scopes_lookup" {
  description = "Skip data source lookups for default Keycloak scopes (set to true for NEW realm deployments to avoid 404 errors during plan phase)"
  type        = bool
  default     = false
}

variable "use_custom_authorities_mapper" {
  description = "Whether to use the custom 'oidc-authorities-mapper' protocol mapper (requires plugin installed)."
  type        = bool
  default     = true
}

# Realm-spezifische Protocol Mapper Overrides
variable "protocol_mapper_overrides" {
  description = "Realm-specific overrides for protocol mapper attributes (e.g., different user_attribute per realm)"
  type = map(object({
    lhmObjectID_user_attribute = optional(string)
    # Weitere Mapper können hier hinzugefügt werden bei Bedarf
  }))
  default = {}

  # Beispiel:
  # protocol_mapper_overrides = {
  #   "public" = {
  #     lhmObjectID_user_attribute = "customObjectID"
  #   }
  # }
}
