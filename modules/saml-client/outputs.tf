output "client_id" {
  description = "Internal Keycloak client ID (UUID)"
  value       = keycloak_saml_client.client.id
}

output "client_roles" {
  description = "Map of created client roles"
  value       = local.all_roles
}
