# Realm Keys / Zertifikats-Management mit Terraform

## 📋 Übersicht

Dieses Modul ermöglicht die Verwaltung von Realm RSA Keys (Zertifikaten) für SAML/OAuth Signaturen in Keycloak via Terraform.

**Use Cases:**
- ✅ Import von PKI-Zertifikaten (z.B. aus interner Zertifizierungsstelle)
- ✅ Zero-Downtime Zertifikatswechsel für SAML-Clients
- ✅ Mehrere aktive Keys gleichzeitig (Overlap während Migration)
- ✅ Automatisierte Key-Rotation

## 🔐 Zertifikatswechsel-Strategie (Zero-Downtime)

### Phase 0: Import existierender Keys (Optional)

Wenn bereits ein Key in Keycloak existiert, der in Terraform verwaltet werden soll:

#### Schritt 1: Provider ID finden

**Variante 1: Keycloak Admin Console**

1. Realm Settings → Keys
2. Klick auf den gewünschten Key  
3. URL: `.../realms/my-realm/keys/abc123-def456-ghi789`

**Variante 2: API**

```bash
curl -s "https://keycloak.example.com/admin/realms/my-realm/keys" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.keys[] | select(.type=="RSA") | .providerId'
```

#### Schritt 2: Import-Block in main.tf hinzufügen

Füge **VOR** dem `module` Block einen `import` Block hinzu:

```terraform
# Import existing realm key
import {
  to = module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-existing"]
  id = "my-realm/abc123-def456-ghi789"
}

module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    "my-realm-existing" = {
      realm_id    = "my-realm"
      name        = "rsa-generated"
      priority    = 200
      certificate = file("certs/existing-cert.pem")
      private_key = file("certs/existing-key.pem")
      enabled     = true
      provider_id = "abc123-def456-ghi789"  # Für Dokumentation
    }
  }
}
```

#### Schritt 3: Terraform Apply

```bash
terraform plan
# Zeigt: will import module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-existing"]

terraform apply
# Import erfolgt automatisch beim Apply!
```

**Nach erfolgreichem Import:**
- ✅ Key ist in Terraform State importiert
- ✅ Terraform verwaltet den Key ab jetzt
- ✅ `provider_id` kann in der Config bleiben (nur für Dokumentation)
- ✅ `import` Block kann entfernt werden (oder bleiben, schadet nicht)

**Wichtig:** Die `certificate` und `private_key` Werte müssen mit dem existierenden Key übereinstimmen, 
sonst will Terraform Updates durchführen!

### Phase 1: Vorbereitung

```terraform
# Nur altes Zertifikat (Current State)
module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    "my-realm-old" = {
      realm_id    = "my-realm"
      name        = "rsa-legacy"
      priority    = 200  # Aktiv für neue Signaturen
      certificate = file("certs/old-cert.pem")
      private_key = file("certs/old-key.pem")
      enabled     = true
    }
  }
}
```

### Phase 2: Neues Zertifikat hinzufügen (BEIDE aktiv!)

```terraform
module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    # Altes Cert: Niedrigere Priority
    "my-realm-old" = {
      realm_id    = "my-realm"
      name        = "rsa-legacy"
      priority    = 100  # ⬇️ Reduziert, aber ENABLED!
      certificate = file("certs/old-cert.pem")
      private_key = file("certs/old-key.pem")
      enabled     = true  # ✅ Bleibt aktiv!
    }
    
    # Neues PKI-Cert: Höhere Priority
    "my-realm-new" = {
      realm_id    = "my-realm"
      name        = "rsa-pki-2025"
      priority    = 200  # ⬆️ Höher = für neue Signaturen
      certificate = file("certs/new-pki-cert.pem")
      private_key = file("certs/new-pki-key.pem")
      enabled     = true
    }
  }
}
```

**Effekt:**
- ✅ Neue SAML Assertions werden mit neuem Cert signiert
- ✅ Alte Assertions können noch mit altem Cert validiert werden
- ✅ SAML Metadata enthält BEIDE Certs
- ✅ Keine Ausfallzeit!

### Phase 3: SAML-Clients migrieren

1. **SAML Metadata URL teilen:**
   ```
   https://keycloak.example.com/realms/my-realm/protocol/saml/descriptor
   ```

2. **Clients aktualisieren:**
   - Trust Store mit neuem Cert konfigurieren
   - Testen der SAML-Authentifizierung
   - Bei Problemen: Rollback möglich (altes Cert noch aktiv!)

3. **Monitoring:**
   ```bash
   # Keycloak Logs prüfen
   kubectl logs -f keycloak-pod | grep "SAML"
   
   # Erfolgreiche Validierungen mit neuem Cert?
   grep "Certificate validation successful" /var/log/keycloak.log
   ```

### Phase 4: Altes Zertifikat deaktivieren

**Nach erfolgreicher Migration aller Clients:**

```terraform
module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    # Altes Cert: DEAKTIVIERT
    "my-realm-old" = {
      realm_id    = "my-realm"
      name        = "rsa-legacy"
      priority    = 0        # ⚠️ Priority 0
      certificate = file("certs/old-cert.pem")
      private_key = file("certs/old-key.pem")
      enabled     = false    # ❌ Deaktiviert
    }
    
    # Neues Cert bleibt aktiv
    "my-realm-new" = {
      realm_id    = "my-realm"
      name        = "rsa-pki-2025"
      priority    = 200
      certificate = file("certs/new-pki-cert.pem")
      private_key = file("certs/new-pki-key.pem")
      enabled     = true
    }
  }
}
```

### Phase 5: Cleanup (nach Bewährungsphase)

**Nach 2-4 Wochen ohne Incidents:**

```terraform
module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    # Nur noch neues Cert
    "my-realm-new" = {
      realm_id    = "my-realm"
      name        = "rsa-pki-2025"
      priority    = 200
      certificate = file("certs/new-pki-cert.pem")
      private_key = file("certs/new-pki-key.pem")
      enabled     = true
    }
    # Altes Cert komplett entfernt ✅
  }
}
```

## 🔒 Sicherheit: Zertifikate NICHT in Git speichern!

### Option 1: GitLab CI/CD Variables (empfohlen)

**GitLab Settings → CI/CD → Variables:**

```yaml
REALM_NEW_CERT:
  Type: File
  Protected: Yes
  Masked: No (zu groß)
  Value: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKZ...
    -----END CERTIFICATE-----

REALM_NEW_KEY:
  Type: File
  Protected: Yes
  Masked: No (zu groß)
  Value: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w...
    -----END PRIVATE KEY-----
```

**Terraform Nutzung:**

```terraform
variable "new_cert_pem" {
  type      = string
  sensitive = true
}

variable "new_key_pem" {
  type      = string
  sensitive = true
}

module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    "my-realm-new" = {
      realm_id    = "my-realm"
      name        = "rsa-pki-2025"
      priority    = 200
      certificate = var.new_cert_pem
      private_key = var.new_key_pem
      enabled     = true
    }
  }
}
```

**In `run_terraform.py` ergänzen:**

```python
# Zertifikate aus Environment Variables laden
cert_pem = os.getenv("REALM_NEW_CERT")
key_pem = os.getenv("REALM_NEW_KEY")

if cert_pem and key_pem:
    tf_vars["new_cert_pem"] = cert_pem
    tf_vars["new_key_pem"] = key_pem
```

### Option 2: HashiCorp Vault (Enterprise)

```terraform
data "vault_generic_secret" "pki_cert" {
  path = "secret/keycloak/realms/my-realm/cert"
}

module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    "my-realm-new" = {
      certificate = data.vault_generic_secret.pki_cert.data["certificate"]
      private_key = data.vault_generic_secret.pki_cert.data["private_key"]
      # ...
    }
  }
}
```

## 📊 Monitoring & Troubleshooting

### 1. Keycloak Admin Console

**Realm Settings → Keys:**
- Prüfen Sie, ob beide Certs sichtbar sind
- Verifizieren Sie die Priorities
- Status "Active" für beide während Migration

### 2. SAML Metadata

```bash
curl https://keycloak.example.com/realms/my-realm/protocol/saml/descriptor \
  | grep -A 10 "KeyDescriptor"
```

**Erwartetes Ergebnis (während Migration):**
- 2x `<KeyDescriptor use="signing">`
- 2x `<X509Certificate>` mit unterschiedlichen Certs

### 3. Client-Side Debugging

**SAML Client Logs:**
```
Certificate validation failed: cert=old-cert.pem
```
→ Client nutzt noch altes Cert, Migration nötig

```
Certificate validation successful: cert=new-pki-cert.pem
```
→ ✅ Client erfolgreich migriert

### 4. Terraform State

```bash
terraform state list | grep realm_key
# module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-old"]
# module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-new"]

terraform state show 'module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-new"]'
```

## ⚠️ Wichtige Hinweise

### 1. `prevent_destroy` Lifecycle

```terraform
lifecycle {
  prevent_destroy = true
}
```

**Schützt vor versehentlichem Löschen aktiver Keys!**

Um einen Key zu löschen:
```bash
# 1. Aus Terraform Config entfernen
# 2. State manuell bereinigen:
terraform state rm 'module.realm_keys.keycloak_realm_keystore_rsa.realm_key["my-realm-old"]'
```

### 2. Priority-Werte

- **0**: Deaktiviert (bleibt aber im System)
- **1-199**: Niedrige Priority (Fallback)
- **200+**: Hohe Priority (aktiv für neue Signaturen)
- **Max: 1000**

### 3. Algorithm Support

Unterstützte Algorithmen:
- `RS256` (empfohlen, Standard)
- `RS384`
- `RS512`
- `PS256`
- `PS384`
- `PS512`

### 4. Certificate Format

**PEM-Format erforderlich:**
```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKZ...
-----END CERTIFICATE-----
```

**Private Key:**
```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w...
-----END PRIVATE KEY-----
```

## 🎯 Best Practices

1. **Overlap-Periode:** Mindestens 2-4 Wochen zwischen Phase 2 und 5
2. **Testen:** Migrations-Workflow zuerst in DEV/TEST durchführen
3. **Monitoring:** SAML-Fehler-Logs während Migration überwachen
4. **Rollback-Plan:** Altes Cert während Migration enabled lassen
5. **Dokumentation:** Client-Liste führen mit Migrations-Status
6. **Backup:** Alte Certs nach Cleanup aufbewahren (außerhalb Terraform)

## 📚 Weitere Ressourcen

- [Keycloak Keys Documentation](https://www.keycloak.org/docs/latest/server_admin/#_realm_keys)
- [Terraform Keycloak Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
- [SAML Certificate Rotation Best Practices](https://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-metadata-errata-2.0-wd-05.html)
