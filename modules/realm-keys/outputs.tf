output "key_ids" {
  description = "Map of created key IDs"
  value       = { for k, v in keycloak_realm_keystore_rsa.realm_key : k => v.id }
}

output "key_priorities" {
  description = "Map of key priorities"
  value       = { for k, v in keycloak_realm_keystore_rsa.realm_key : k => v.priority }
}

output "active_keys" {
  description = "Map of keys marked as active"
  value       = { for k, v in keycloak_realm_keystore_rsa.realm_key : k => v.enabled }
}

output "import_instructions" {
  description = "Import instructions for keys with provider_id"
  value = length([for k, v in var.realm_keys : k if v.provider_id != null]) > 0 ? join("\n", concat(
    ["# Keys mit provider_id gefunden - Import erforderlich:"],
    [for k, v in var.realm_keys : 
      "terraform import 'module.realm_keys.keycloak_realm_keystore_rsa.realm_key[\"${k}\"]' '${v.realm_id}/${v.provider_id}'"
      if v.provider_id != null
    ]
  )) : "# Keine Keys mit provider_id - kein Import erforderlich"
}
