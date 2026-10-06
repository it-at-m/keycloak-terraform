# Hybrid API Workaround für Realm Keys

## Problem

Der Keycloak Terraform Provider nutzt `realm_id` sowohl für:
- **URL-Pfade**: `/admin/realms/{realm_id}/components` 
- **Component parentId**: `{"parentId": "{realm_id}"}`

Bei Realms mit **Name/ID Mismatch** (z.B. `name="public"`, `id="Public"`) schlägt die Key-Erstellung fehl:
```
Error: 404 Not Found at /auth/admin/realms/Public/components
```

## Lösung: Hybrid-Ansatz

**Terraform** managed Scopes, Themes, Clients etc. (funktioniert normal)  
**Keycloak Admin API** erstellt Keys für problematische Realms

### Workflow

1. **Konfiguration** in `main.tf` bleibt sichtbar:
   ```terraform
   realm_keys = {
     "my-key" = {
       realm_id = "public"
       use_api_workaround = "Public"  # ← Parent ID für API-Erstellung (z.B. "Public", "test", etc.)
       # ... rest
     }
   }
   ```

2. **`run_terraform.py`** orchestriert:
   - Parst `main.tf` → findet Keys mit `use_api_workaround="<ParentID>"`
   - Erstellt diese Keys via **Keycloak Admin API** mit der angegebenen Parent ID
   - Terraform managed **alles andere** (ohne API-Keys im State)

## Verwendung

### 1. Environment konfigurieren

```json
// Terraform/envs.config.json
{
  "environments": {
    "test": {
      "realm_name_id_mismatches": {
        "public": {
          "name": "public",
          "id": "Public"
        }
      }
    }
  }
}
```

### 2. Keys in main.tf markieren

```terraform
// Terraform/environments/test/main.tf
module "realm_keys" {
  source = "../../modules/realm-keys"
  
  realm_keys = {
    "public-realm-new-2025" = {
      realm_id           = "public"
      name               = "rsa-pki-2025-TEST"
      priority           = 50
      certificate        = var.public_realm_cert
      private_key        = var.public_realm_key
      algorithm          = "RS256"
      use_api_workaround = "Public"  # ← Parent ID für API-Erstellung
    }
  }
}
```

### 3. Terraform ausführen

```bash
# Lokal
python run_terraform.py --env test --action plan --client-secret $SECRET

# CI/CD (automatisch)
# Script erkennt Mismatches und nutzt API
```

## Technische Details

### API-Erstellung (apply)

```python
# run_terraform.py - Vereinfachter Flow

1. Parse realm_keys aus main.tf
2. Filtere Keys mit use_api_workaround="<ParentID>" (nicht leer)
3. Für jeden API-Key:
   GET /admin/realms/{realm_id}/components?parent={ParentID}
   → Prüfe ob Key existiert
   
   POST /admin/realms/{realm_id}/components
   {
     "parentId": "{ParentID}",  // ← Nutzt custom Parent ID!
     "name": "...",
     "config": {...}
   }
   
4. Terraform apply (ohne API-Keys)
```

### API-Löschung (destroy)

```python
1. Parse realm_keys
2. Für jeden API-Key:
   DELETE /admin/realms/{name}/components/{id}
   
3. Terraform destroy (ohne API-Keys)
```

## CI/CD-Kompatibilität

✅ **Vollautomatisch** - keine manuellen Schritte  
✅ **Idempotent** - Script prüft Existenz vor Create/Update  
✅ **Fehlerbehandlung** - API-Fehler werden geloggt  
✅ **Secrets** - Nutzt vorhandene CI/CD Variables

## Vorteile

1. ✅ **Keine Realm-Umbenennung** - keine Ausfallzeiten
2. ✅ **Keine DB-Änderungen** - keine Constraints-Probleme  
3. ✅ **Terraform-Kompatibel** - Konfiguration bleibt in main.tf
4. ✅ **Transparent** - Logs zeigen API-Operationen
5. ✅ **Wartbar** - Zertifikat-Rotation funktioniert normal

## Nachteile

⚠️ **State-Drift** - API-Keys sind nicht im Terraform State  
   → Manuelle Änderungen via GUI werden nicht erkannt

⚠️ **Destroy begrenzt** - Keys müssen manuell via API gelöscht werden  
   → Script unterstützt nur delete bei destroy-Action

## Langfristige Lösung

**Export/Import** des `public` Realms mit UUID-Korrektur:
1. Export: `kc.sh export --realm public --file public.json`
2. Edit JSON: `"id": "Public"` → `"id": "public"`
3. Re-Import als neuer Realm
4. Clients migrieren
5. Alten Realm löschen

→ Danach funktioniert Terraform normal ohne API-Workaround

## Troubleshooting

### Keys werden nicht erstellt

**Check 1**: `use_api_workaround = "<ParentID>"` gesetzt?
```terraform
use_api_workaround = "Public"  # Für public realm
use_api_workaround = "test"    # Für intra realm
```

**Check 2**: Logs prüfen:
```
🔑 Gefunden: 2 Key(s) mit API-Workaround
📝 Erstelle/Update Keys via Keycloak Admin API...
   ✅ Created via API: rsa-pki-2025-TEST (Priority: 50, Algo: RS256)
```

### Terraform versucht Keys zu erstellen

→ `use_api_workaround = "<ParentID>"` fehlt in main.tf  
→ Modul filtert Keys via `locals.terraform_managed_keys`

### API-Fehler 401 Unauthorized

→ Token abgelaufen oder ungültig  
→ TokenManager sollte automatisch refreshen

## Testing

```bash
# 1. Parse-Test (kein API-Call)
python -c "from run_terraform import parse_realm_keys_from_main_tf; \
  print(parse_realm_keys_from_main_tf('Terraform/environments/test/main.tf'))"

# 2. Terraform Plan (Dry-Run)
python run_terraform.py --env test --action plan --client-secret $SECRET

# 3. Verifiziere Keys via API
python ci-tools/keycloak/list_realm_keys.py $SECRET
```

## Siehe auch

- `Terraform/run_terraform.py` - Implementierung
- `ci-tools/keycloak/list_realm_keys.py` - Key-Verifikation
- `TERRAFORM_BACKEND_SETUP.md` - GitLab State Management
