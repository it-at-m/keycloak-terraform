output "settings" {
  description = "Map Realm-ID -> aufgelöste Token-/Session-Lebensdauern (Default oder Override). Zum direkten Verdrahten in die jeweilige keycloak_realm-Ressource, z.B. sso_session_idle_timeout = module.realm_session_lifetimes.settings[\"ciam-dev\"].sso_session_idle_timeout"
  value       = local.settings
}
