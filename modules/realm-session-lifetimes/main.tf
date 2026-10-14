# Token-/Session-Lebensdauern sind Top-Level-Attribute der Ressource
# "keycloak_realm" selbst (keine eigene Sub-Ressource im Provider). Für
# Realms, die bereits an anderer Stelle als "keycloak_realm"-Ressource
# verwaltet werden (z.B. ciam-dev, wahl-dev), berechnet dieses Modul nur die
# aufgelösten Werte (local.settings); der Call-Site verdrahtet sie selbst.
#
# Für Vor-Terraform-Realms ohne eigene "keycloak_realm"-Ressource (z.B.
# IBS53) legt dieses Modul zusätzlich selbst eine schmal geschnittene
# "keycloak_realm"-Ressource an (var.owned_realm_id) - analog zu
# modules/realm-themes: Nur die 10 Session-Felder werden verwaltet, alles
# andere ist per lifecycle.ignore_changes geschützt, damit kein anderes,
# bereits konfiguriertes Realm-Attribut überschrieben wird. Siehe ADR-006.

terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

locals {
  defaults = {
    sso_session_idle_timeout             = var.sso_session_idle_timeout
    sso_session_max_lifespan             = var.sso_session_max_lifespan
    revoke_refresh_token                 = var.revoke_refresh_token
    refresh_token_max_reuse              = var.refresh_token_max_reuse
    access_token_lifespan                = var.access_token_lifespan
    offline_session_idle_timeout         = var.offline_session_idle_timeout
    offline_session_max_lifespan_enabled = var.offline_session_max_lifespan_enabled
    offline_session_max_lifespan         = var.offline_session_max_lifespan
    access_code_lifespan_login           = var.access_code_lifespan_login
    access_code_lifespan_user_action     = var.access_code_lifespan_user_action
  }

  settings = {
    for realm in var.realm_id : realm => merge(
      local.defaults,
      { for k, v in try(var.session_lifetime_overrides[realm], {}) : k => v if v != null }
    )
  }
}

# Schmal geschnittene keycloak_realm-Ressource für Vor-Terraform-Realms ohne
# eigene keycloak_realm-Ressource an anderer Stelle (var.owned_realm_id).
# MUSS vor dem ersten Apply importiert werden (terraform import bzw. ein
# entsprechender `import`-Block, siehe run_terraform.py) - der Realm
# existiert bereits in Keycloak.
resource "keycloak_realm" "managed" {
  for_each = toset(var.owned_realm_id)

  realm = each.key

  sso_session_idle_timeout             = local.settings[each.key].sso_session_idle_timeout
  sso_session_max_lifespan             = local.settings[each.key].sso_session_max_lifespan
  revoke_refresh_token                 = local.settings[each.key].revoke_refresh_token
  refresh_token_max_reuse              = local.settings[each.key].refresh_token_max_reuse
  access_token_lifespan                = local.settings[each.key].access_token_lifespan
  offline_session_idle_timeout         = local.settings[each.key].offline_session_idle_timeout
  offline_session_max_lifespan_enabled = local.settings[each.key].offline_session_max_lifespan_enabled
  offline_session_max_lifespan         = local.settings[each.key].offline_session_max_lifespan
  access_code_lifespan_login           = local.settings[each.key].access_code_lifespan_login
  access_code_lifespan_user_action     = local.settings[each.key].access_code_lifespan_user_action

  lifecycle {
    ignore_changes = [
      # Alles außer den 10 Session-Feldern oben bleibt unangetastet -
      # dieses Modul verwaltet ausschließlich Token-/Session-Lebensdauern.
      display_name,
      display_name_html,
      enabled,
      user_managed_access,
      admin_permissions_enabled,
      organizations_enabled,
      terraform_deletion_protection,
      attributes,
      default_default_client_scopes,
      default_optional_client_scopes,
      # Themes
      login_theme,
      admin_theme,
      account_theme,
      email_theme,
      # Security
      ssl_required,
      password_policy,
      default_signature_algorithm,
      # Login
      registration_allowed,
      registration_email_as_username,
      edit_username_allowed,
      reset_password_allowed,
      remember_me,
      verify_email,
      login_with_email_allowed,
      duplicate_emails_allowed,
      # Sonstige Token-/Lifespan-Felder, die NICHT zu den 10 verwalteten gehören
      access_code_lifespan,
      access_token_lifespan_for_implicit_flow,
      action_token_generated_by_user_lifespan,
      action_token_generated_by_admin_lifespan,
      client_session_idle_timeout,
      client_session_max_lifespan,
      sso_session_idle_timeout_remember_me,
      sso_session_max_lifespan_remember_me,
      oauth2_device_code_lifespan,
      oauth2_device_polling_interval,
      # Flows
      browser_flow,
      client_authentication_flow,
      direct_grant_flow,
      docker_authentication_flow,
      registration_flow,
      reset_credentials_flow,
      first_broker_login_flow,
      # Blöcke
      internationalization,
      security_defenses,
      smtp_server,
      otp_policy,
      web_authn_policy,
      web_authn_passwordless_policy,
    ]
  }
}
