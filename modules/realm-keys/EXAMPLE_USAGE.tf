# # Beispiel: Realm-Zertifikatswechsel mit PKI-Zertifikat
# # =======================================================
# # Dieses Beispiel zeigt die Migration von einem alten zu einem neuen Zertifikat

# # ========================================
# # OPTION 1: Import existierender Keys
# # ========================================
# # Wenn ein Key bereits in Keycloak existiert und unter Terraform-Kontrolle gebracht werden soll:

# module "realm_keys_import" {
#   source = "../../modules/realm-keys"
  
#   realm_keys = {
#     # Existierender Key - wird importiert statt neu erstellt
#     "my-realm-existing" = {
#       realm_id    = "my-realm"
#       name        = "rsa-generated"
#       priority    = 200
#       certificate = file("${path.module}/certs/existing-cert.pem")
#       private_key = file("${path.module}/certs/existing-key.pem")
#       enabled     = true
#       provider_id = "abc123-def456-ghi789"  # ⬅️ Provider ID aus Keycloak
#     }
#   }
# }

# # Provider ID finden:
# # 1. Keycloak Admin Console → Realm Settings → Keys → Click auf Key
# # 2. URL: .../realms/my-realm/keys/abc123-def456-ghi789
# # 3. Oder via API:
# #    curl "https://keycloak.example.com/admin/realms/my-realm/keys" \
# #      -H "Authorization: Bearer $TOKEN" | jq -r '.keys[] | .providerId'

# # ========================================
# # OPTION 2: Neue Keys erstellen
# # ========================================

# module "realm_keys" {
#   source = "../../modules/realm-keys"
  
#   realm_keys = {
#     # PHASE 1: Altes Zertifikat (niedrige Priority)
#     # Bleibt aktiv für bestehende SAML-Clients während Migration
#     "my-realm-old-cert" = {
#       realm_id    = "my-realm"
#       name        = "rsa-legacy-2024"
#       priority    = 100  # Niedrigere Priority = nicht für neue Signaturen
#       certificate = file("${path.module}/certs/old-cert.pem")
#       private_key = file("${path.module}/certs/old-key.pem")
#       enabled     = true  # WICHTIG: Bleibt enabled während Migration!
#       algorithm   = "RS256"
#       # provider_id wird NICHT angegeben = neuer Key wird erstellt
#     }
    
#     # PHASE 2: Neues PKI-Zertifikat (hohe Priority)
#     # Wird für neue Signaturen verwendet
#     "my-realm-new-pki-cert" = {
#       realm_id    = "my-realm"
#       name        = "rsa-pki-2025"
#       priority    = 200  # Höhere Priority = aktiv für neue Signaturen
#       certificate = file("${path.module}/certs/new-pki-cert.pem")
#       private_key = file("${path.module}/certs/new-pki-key.pem")
#       enabled     = true
#       algorithm   = "RS256"
#     }
#   }
# }

# # Alternative: Zertifikate aus GitLab CI/CD Variables
# # =====================================================
# # SICHERER: Keine Zertifikate im Git-Repository!

# # In .gitlab-ci.yml oder als CI/CD Variable:
# # REALM_NEW_CERT: |
# #   -----BEGIN CERTIFICATE-----
# #   MIIDXTCCAkWgAwIBAgIJAKZ...
# #   -----END CERTIFICATE-----
# # 
# # REALM_NEW_KEY: |
# #   -----BEGIN PRIVATE KEY-----
# #   MIIEvQIBADANBgkqhkiG9w...
# #   -----END PRIVATE KEY-----

# # Terraform Konfiguration mit Variablen:
# variable "new_cert_pem" {
#   description = "New PKI certificate in PEM format"
#   type        = string
#   sensitive   = true
# }

# variable "new_key_pem" {
#   description = "New PKI private key in PEM format"
#   type        = string
#   sensitive   = true
# }

# # Nutzung:
# # module "realm_keys" {
# #   source = "../../modules/realm-keys"
# #   
# #   realm_keys = {
# #     "my-realm-new-pki-cert" = {
# #       realm_id    = "my-realm"
# #       name        = "rsa-pki-2025"
# #       priority    = 200
# #       certificate = var.new_cert_pem
# #       private_key = var.new_key_pem
# #       enabled     = true
# #     }
# #   }
# # }

# # MIGRATION WORKFLOW:
# # ===================
# # 
# # 1. INITIAL STATE (nur altes Cert):
# #    - priority: 200
# #    - enabled: true
# # 
# # 2. ADD NEW CERT (beide aktiv):
# #    terraform apply
# #    - old_cert: priority 100, enabled: true
# #    - new_cert: priority 200, enabled: true
# #    → Neue Signaturen mit new_cert, alte Validierungen funktionieren noch
# # 
# # 3. SAML CLIENTS MIGRIEREN:
# #    - SAML Metadata URL teilen: /realms/{realm}/protocol/saml/descriptor
# #    - Clients updaten ihre Trust Stores
# #    - Testen pro Client
# # 
# # 4. DEACTIVATE OLD CERT (nach erfolgreicher Migration):
# #    - old_cert: priority 0, enabled: false
# #    terraform apply
# # 
# # 5. CLEANUP (nach Bewährungsphase, z.B. 4 Wochen):
# #    - old_cert komplett aus Terraform Config entfernen
# #    terraform apply
# #    → lifecycle: prevent_destroy = true verhindert versehentliches Löschen

# # WICHTIG für SAML:
# # =================
# # - Keycloak fügt ALLE aktiven Certs ins SAML Metadata ein
# # - Clients können gegen BEIDE Certs validieren
# # - Priority bestimmt nur, welches für NEUE Signaturen genutzt wird
# # - Minimale Ausfallzeit durch Overlap-Periode!

# # TROUBLESHOOTING:
# # ================
# # Falls SAML-Validierung fehlschlägt:
# # 1. Prüfen Sie Keycloak Admin Console → Realm Settings → Keys
# # 2. Beide Certs sollten sichtbar sein mit korrekten Priorities
# # 3. SAML Metadata prüfen: /realms/{realm}/protocol/saml/descriptor
# # 4. Client-Logs prüfen auf Certificate-Validation-Errors
