output "client_id" {
  description = "Interne Keycloak Client ID (UUID)"
  value       = module.oidc_client.client_id
}

output "client_secret" {
  description = "Client Secret (sensitive)"
  value       = module.oidc_client.client_secret
  sensitive   = true
}

output "client_roles" {
  description = "Map der erstellten Client-Rollen (Name -> Keycloak Role ID)"
  value       = module.oidc_client.client_roles
}
