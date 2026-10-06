# LHM Demo Realm - Automated Deployment

## Problem: Roles Scope Configuration

Keycloak erstellt beim Realm-Anlegen automatisch einen `roles` Client Scope mit `include_in_token_scope = false`. Da dieser Scope VOR Terraform existiert, kann Terraform ihn nicht direkt erstellen oder ändern.

## Lösung: Automatisierte Terraform-Befehlskette

Die Deployment-Skripte führen automatisch folgende Schritte aus:

```bash
1. terraform apply -target=...    # Erstellt Realm
2. terraform import ...           # Importiert roles scope in State
3. terraform apply                # Aktualisiert include_in_token_scope = true
```

## Verwendung

### Linux/macOS (Container)

```bash
./deploy-lhm-demo.sh <client_secret>
```

### Windows (PowerShell)

```powershell
.\deploy-lhm-demo.ps1 -ClientSecret "your-secret"
```

### Docker/OpenTofu Container

```dockerfile
# Im Dockerfile oder docker-compose.yml
RUN chmod +x /terraform/environments/local/deploy-lhm-demo.sh
CMD ["/terraform/environments/local/deploy-lhm-demo.sh", "${CLIENT_SECRET}"]
```

Oder in einem CI/CD Pipeline:

```yaml
# .gitlab-ci.yml
deploy-lhm-demo:
  stage: deploy
  image: ghcr.io/opentofu/opentofu:latest
  script:
    - cd Terraform/environments/local
    - chmod +x deploy-lhm-demo.sh
    - ./deploy-lhm-demo.sh ${CLIENT_SECRET}
```

## Was passiert automatisch?

### Schritt 1: Realm Basis-Erstellung
```bash
terraform apply -target=keycloak_realm.lhm_demo \
                -target=module.lhm_demo_scopes \
                -target=keycloak_realm_user_profile.lhm_demo_profile
```

Erstellt:
- Realm `LHM-Demo`
- Custom Scopes (lhm-core, LHM, LHM_Extended)
- User Profile Konfiguration
- Keycloak erstellt automatisch Standard-Scopes (inkl. `roles`)

### Schritt 2: Roles Scope Import
```bash
terraform import keycloak_openid_client_scope.roles_managed LHM-Demo/roles
```

Importiert den automatisch erstellten `roles` scope in den Terraform State.

### Schritt 3: Vollständiges Deployment
```bash
terraform apply
```

Erstellt:
- Alle Clients (Backend, Frontend)
- User Accounts
- Role Assignments
- **Aktualisiert roles scope: `include_in_token_scope = true`** ✅

## Manuelle Ausführung (ohne Skript)

Falls Sie die Schritte manuell ausführen möchten:

```bash
# 1. Realm erstellen
terraform apply -auto-approve -var="client_secret=XXX" \
    -target=keycloak_realm.lhm_demo \
    -target=module.lhm_demo_scopes \
    -target=keycloak_realm_user_profile.lhm_demo_profile

# 2. Roles scope importieren
terraform import -var="client_secret=XXX" \
    keycloak_openid_client_scope.roles_managed \
    LHM-Demo/roles

# 3. Vollständig deployen
terraform apply -auto-approve -var="client_secret=XXX"
```

## Verifikation

Nach erfolgreichem Deployment:

```bash
# Check Terraform State
terraform state show keycloak_openid_client_scope.roles_managed

# Erwartete Ausgabe:
# include_in_token_scope = true  ✓
```

Oder in Keycloak Admin UI:
1. http://localhost:8080/auth/admin
2. Realm: **LHM-Demo** → **Client Scopes** → **roles**
3. Tab: **Settings**
4. **Include in Token Scope**: ✓ Enabled

## Warum diese Lösung?

✅ **Vollautomatisch** - Keine manuelle Konfiguration erforderlich  
✅ **CI/CD-ready** - Funktioniert in Containern ohne Benutzerinteraktion  
✅ **Idempotent** - Kann mehrfach ausgeführt werden  
✅ **Keine externen Dependencies** - Nur Terraform/OpenTofu  
✅ **Kein manueller Import** - Skript übernimmt alles

## Troubleshooting

### Error: "Resource already exists"
```bash
# Lösung: State bereinigen und neu starten
terraform state rm keycloak_openid_client_scope.roles_managed
./deploy-lhm-demo.sh <client_secret>
```

### Error: "Cannot import non-existent object"
```bash
# Das Realm existiert noch nicht
# Lösung: Nur Schritt 1 ausführen, dann Import
terraform apply -target=keycloak_realm.lhm_demo
terraform import keycloak_openid_client_scope.roles_managed LHM-Demo/roles
terraform apply
```

### Scope hat immer noch `include_in_token_scope = false`
```bash
# State und Resource sind out-of-sync
# Lösung: Force refresh
terraform state rm keycloak_openid_client_scope.roles_managed
terraform import keycloak_openid_client_scope.roles_managed LHM-Demo/roles
terraform apply -refresh=true
```
