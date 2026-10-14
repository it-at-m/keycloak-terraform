output "client_id" {
  description = "Interne Keycloak Client ID (UUID)"
  value       = module.saml_client.client_id
}

output "client_roles" {
  description = "Map der erstellten Client-Rollen (Name -> Keycloak Role ID)"
  value       = module.saml_client.client_roles
}
