variable "client_id" {
  description = "Service account client ID"
  type        = string
}

variable "client_secret" {
  description = "Service account client secret"
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "realm" {
  description = "Realm for authentication (usually 'master')"
  type        = string
  default     = "master"
}

variable "realm_id" {
  description = "List of realm IDs to configure themes for"
  type        = list(string)
}

variable "login_theme" {
  description = "Login theme name"
  type        = string
  default     = "lhm-default.v2"
}

variable "admin_theme" {
  description = "Admin console theme name"
  type        = string
  default     = "lhm-admin"
}

variable "account_theme" {
  description = "Account management theme name (optional)"
  type        = string
  default     = ""
}

variable "email_theme" {
  description = "Email theme name (optional)"
  type        = string
  default     = ""
}

variable "supported_locales" {
  description = "List of supported locales"
  type        = list(string)
  default     = ["de", "en"]
}

variable "default_locale" {
  description = "Default locale"
  type        = string
  default     = "de"
}
