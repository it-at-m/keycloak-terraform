output "realm_ids" {
  description = "Map of configured realm IDs"
  value       = { for k, v in keycloak_realm.realm_theme : k => v.id }
}

output "login_themes" {
  description = "Map of configured login themes per realm"
  value       = { for k, v in keycloak_realm.realm_theme : k => v.login_theme }
}

output "admin_themes" {
  description = "Map of configured admin themes per realm"
  value       = { for k, v in keycloak_realm.realm_theme : k => v.admin_theme }
}
