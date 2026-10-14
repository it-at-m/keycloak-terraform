variable "realm_id" {
  description = "Liste der Realm-IDs, für die Token-/Session-Lebensdauern berechnet werden sollen."
  type        = list(string)
}

variable "owned_realm_id" {
  description = <<-EOT
    Teilmenge von var.realm_id: Realms, für die dieses Modul selbst eine
    schmal geschnittene keycloak_realm-Ressource anlegt (nur die 10
    Session-Felder, alles andere per lifecycle.ignore_changes geschützt).

    Nur für Vor-Terraform-Realms setzen, die AN KEINER ANDEREN STELLE bereits
    eine eigene keycloak_realm-Ressource haben (z.B. IBS53) - sonst würden
    zwei Terraform-Ressourcen denselben Realm verwalten. Muss vor dem ersten
    Apply importiert werden (siehe run_terraform.py / ADR-006), da der Realm
    bereits in Keycloak existiert.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.owned_realm_id : contains(var.realm_id, r)])
    error_message = "Jeder Realm in owned_realm_id muss auch in realm_id enthalten sein."
  }
}

# =============================================================================
# Globale Defaults: Folgen noch nicht den (Best Practice Empfehlung IDP, siehe docs/oidc-integration.md
# bzw. docs/saml-integration.md im idp-Repo - "Token- & Session-Lebensdauern")
# =============================================================================

variable "sso_session_idle_timeout" {
  description = "SSO Session Idle Timeout (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "10h"
}

variable "sso_session_max_lifespan" {
  description = "SSO Session Max Lifespan (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "12h"
}

variable "revoke_refresh_token" {
  description = "Refresh Token Rotation aktivieren (Single-Use statt unbegrenzt wiederverwendbar)"
  type        = bool
  default     = true
}

variable "refresh_token_max_reuse" {
  description = "Maximale Wiederverwendung eines Refresh Tokens, bevor es widerrufen wird (nur relevant wenn revoke_refresh_token = true; 0 = Single-Use)"
  type        = number
  default     = 5
}

variable "access_token_lifespan" {
  description = "Access Token Lifespan (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "5m"
}

variable "offline_session_idle_timeout" {
  description = "Offline Session Idle Timeout (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "168h" # 7 Tage
}

variable "offline_session_max_lifespan_enabled" {
  description = "Offline Session Max Lifespan begrenzen (verhindert unbegrenzt gültige Offline Tokens)"
  type        = bool
  default     = true
}

variable "offline_session_max_lifespan" {
  description = "Offline Session Max Lifespan (Best Practice IDP-Vorgabe, nur relevant wenn offline_session_max_lifespan_enabled = true)"
  type        = string
  default     = "720h" # 30 Tage
}

variable "access_code_lifespan_login" {
  description = "Login Timeout - maximale Zeit, die ein Nutzer auf der Login-Seite verweilen darf (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "30m"
}

variable "access_code_lifespan_user_action" {
  description = "Login Action Timeout - maximale Zeit für Folgeaktionen wie Passwort-Update (Best Practice IDP-Vorgabe)"
  type        = string
  default     = "5m"
}

# =============================================================================
# Realm-spezifische Overrides
# =============================================================================

variable "session_lifetime_overrides" {
  description = <<-EOT
    Realm-spezifische Overrides der Token-/Session-Lebensdauern. Nur die
    Felder, die für einen Realm explizit gesetzt werden, überschreiben den
    globalen Default (var.sso_session_idle_timeout etc.) - alle anderen
    Felder bleiben beim jeweiligen Default. Key = Realm-ID (wie in var.realm_id).

    Beispiel:
    session_lifetime_overrides = {
      "ciam-predev" = {
        sso_session_idle_timeout = "1h"
      }
    }
  EOT
  type = map(object({
    sso_session_idle_timeout             = optional(string)
    sso_session_max_lifespan             = optional(string)
    revoke_refresh_token                 = optional(bool)
    refresh_token_max_reuse              = optional(number)
    access_token_lifespan                = optional(string)
    offline_session_idle_timeout         = optional(string)
    offline_session_max_lifespan_enabled = optional(bool)
    offline_session_max_lifespan         = optional(string)
    access_code_lifespan_login           = optional(string)
    access_code_lifespan_user_action     = optional(string)
  }))
  default = {}
}
