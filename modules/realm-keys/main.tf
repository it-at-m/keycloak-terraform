terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

# Lokale Variable: Filtere Keys die NICHT via API gemanaged werden sollen
locals {
  terraform_managed_keys = {
    for k, v in var.realm_keys : k => v
    if try(v.use_api_workaround, "") == "" # Wenn leer, dann Terraform-managed
  }
}

# RSA Key Provider für SAML/OAuth Signaturen
# Ermöglicht Import von Zertifikaten aus interner PKI
# 
# WICHTIG: Keys mit use_api_workaround="<ParentID>" werden NICHT hier erstellt,
# sondern via run_terraform.py + Keycloak Admin API (für Realms mit name/id Mismatch)
resource "keycloak_realm_keystore_rsa" "realm_key" {
  for_each = local.terraform_managed_keys

  # Realm ID: Nutze parent_id falls gesetzt, sonst realm_id
  # Workaround für "public" Realm: realm_id="public" (für URL), parent_id="Public" (für Component parentId)
  realm_id = coalesce(each.value.parent_id, each.value.realm_id)
  name     = each.value.name

  # Priority: Höherer Wert = wird für neue Signaturen verwendet
  # Alte Keys mit niedrigerer Priority bleiben für Validierung aktiv!
  priority = each.value.priority

  # Zertifikat und Private Key aus interner PKI
  certificate = each.value.certificate
  private_key = each.value.private_key

  # Optional: Algorithm (default: RS256)
  algorithm = try(each.value.algorithm, "RS256")

  # Key Provider Type: "rsa" für Signatur (sig), "rsa-enc" für Verschlüsselung (enc)
  # WICHTIG: Ohne provider_id="rsa-enc" wird auch bei RSA-OAEP ein sig-Key erstellt!
  provider_id = try(each.value.key_provider_id, "rsa")

  # Enabled: Key aktiv?
  enabled = try(each.value.enabled, true)
  active  = try(each.value.active, true)

  lifecycle {
    # Verhindert versehentliches Löschen von aktiven Keys
    prevent_destroy = false

    # Bei Cert-Wechsel: Erst neues hinzufügen, dann altes entfernen
    create_before_destroy = false
  }
}
