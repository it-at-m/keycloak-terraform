terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

provider "keycloak" {
  client_id     = var.client_id
  client_secret = var.client_secret
  url           = var.keycloak_url
  realm         = var.realm
}

# Realm Theme Configuration (für EXISTIERENDE Realms)
# Wichtig: Verwendet lifecycle ignore_changes für Attribute, die wir NICHT verwalten wollen
resource "keycloak_realm" "realm_theme" {
  for_each = toset(var.realm_id)

  realm   = each.key
  enabled = true

  # Theme Settings - NUR diese verwalten wir
  login_theme   = var.login_theme
  admin_theme   = var.admin_theme
  account_theme = var.account_theme != "" ? var.account_theme : null
  email_theme   = var.email_theme != "" ? var.email_theme : null

  # Internationalization
  internationalization {
    supported_locales = var.supported_locales
    default_locale    = var.default_locale
  }

  # Lifecycle: Alle anderen Realm-Attribute ignorieren
  # So wird der Realm NICHT neu erstellt, sondern nur aktualisiert
  # (Liste abgeglichen mit modules/realm-session-lifetimes - dort werden
  # umgekehrt die Theme-Felder ignoriert; internationalization wird hier
  # bewusst NICHT ignoriert, da dieses Modul sie aktiv verwaltet)
  lifecycle {
    ignore_changes = [
      # Ignoriere alle Attribute außer Themes
      enabled,
      display_name,
      display_name_html,
      user_managed_access,
      admin_permissions_enabled,
      organizations_enabled,
      terraform_deletion_protection,
      attributes,
      default_default_client_scopes,
      default_optional_client_scopes,
      # Security
      ssl_required,
      password_policy,
      # Login
      registration_allowed,
      registration_email_as_username,
      edit_username_allowed,
      reset_password_allowed,
      remember_me,
      verify_email,
      login_with_email_allowed,
      duplicate_emails_allowed,
      # Token
      default_signature_algorithm,
      revoke_refresh_token,
      refresh_token_max_reuse,
      sso_session_idle_timeout,
      sso_session_max_lifespan,
      sso_session_idle_timeout_remember_me,
      sso_session_max_lifespan_remember_me,
      offline_session_idle_timeout,
      offline_session_max_lifespan,
      client_session_idle_timeout,
      client_session_max_lifespan,
      access_token_lifespan,
      access_token_lifespan_for_implicit_flow,
      access_code_lifespan,
      access_code_lifespan_login,
      access_code_lifespan_user_action,
      action_token_generated_by_user_lifespan,
      action_token_generated_by_admin_lifespan,
      oauth2_device_code_lifespan,
      oauth2_device_polling_interval,
      # SMTP
      smtp_server,
      # Security Defenses
      security_defenses,
      # Flows
      browser_flow,
      client_authentication_flow,
      direct_grant_flow,
      docker_authentication_flow,
      registration_flow,
      reset_credentials_flow,
      first_broker_login_flow,
      # OTP
      otp_policy,
      # Web Authn
      web_authn_policy,
      web_authn_passwordless_policy,
    ]
  }
}
