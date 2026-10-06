# LHM Demo Setup - README
# =======================

## Überblick

Diese Terraform-Konfiguration erstellt eine vollständige LHM Demo-Umgebung mit:

### 1. **Realm: LHM-Demo**
- Unmanaged Attributes aktiviert (für LDAP-Attribute)
- LHM Standard Themes (lhm-default.v2)
- Security Defenses (Brute Force Protection, CSP Headers)
- Token Lifespans nach LHM-Standard

### 2. **Standard LHM Scopes**
Über das `realm-scopes` Modul werden folgende Scopes erstellt:
- `lhm-core` - LHM Standard Scope (enthält lhmObjectID, department, telephoneNumber)
- `LHM` - ⚠️ DEPRECATED Legacy Scope
- `LHM_Extended` - ⚠️ DEPRECATED Extended Scope (dn, memberOf, authorities)
- `roles` - OpenID Connect Standard Scope (include.in.token.scope=true)

### 3. **OIDC Confidential Client: lhm-demo-backend**
- **Client Type:** Confidential (mit Client Secret)
- **Flows:** Authorization Code, Resource Owner Password, Client Credentials
- **URLs:** 
  - Production: `https://demo-backend.muenchen.de`
  - Local: `http://localhost:8080`
- **Scopes:**
  - Default: `profile`, `email`, `lhm-core`
  - Optional: `roles`, `LHM`, `LHM_Extended`
- **Rollen:**
  - `lhm-ab-demo-backend-admin` → Composite → `admin`
  - `admin` - Voller Zugriff
  - `lhm-ab-demo-backend-tester` → Composite → `tester`
  - `tester` - Test-Zugriff
  - `viewer` - Lesender Zugriff

### 4. **OIDC Public Client: lhm-demo-frontend**
- **Client Type:** Public (kein Secret, für SPAs)
- **Flows:** Authorization Code mit PKCE
- **URLs:**
  - Production: `https://demo-frontend.muenchen.de`
  - Local: `http://localhost:3000`, `http://localhost:5173` (Vite)
- **Scopes:**
  - Default: `profile`, `email`, `lhm-core`
  - Optional: `roles`, `LHM`
- **Rollen:** Gleiche Struktur wie Backend

### 5. **Demo-Benutzer**

#### Maria Admin (`maria.admin`)
- **Email:** maria.admin@muenchen.de
- **Password:** `Demo123!Admin` (temporary)
- **Department:** IT-Referat - Identity & Access Management
- **Telefon:** +49 89 233-11111
- **Rollen:** Admin in Backend + Frontend
- **memberOf:** 
  - `CN=lhm-ab-demo-backend-admin,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`
  - `CN=lhm-ab-demo-frontend-admin,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`
  - `CN=IT-Admins,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`

#### Thomas Tester (`thomas.tester`)
- **Email:** thomas.tester@muenchen.de
- **Password:** `Demo123!Test` (temporary)
- **Department:** IT-Referat - Qualitätssicherung
- **Telefon:** +49 89 233-22222
- **Rollen:** Tester in Backend + Frontend
- **memberOf:**
  - `CN=lhm-ab-demo-backend-tester,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`
  - `CN=lhm-ab-demo-frontend-tester,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`
  - `CN=QA-Team,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`

#### Julia Viewer (`julia.viewer`)
- **Email:** julia.viewer@muenchen.de
- **Password:** `Demo123!View` (temporary)
- **Department:** IT-Referat - Anwendungsbetreuung
- **Telefon:** +49 89 233-33333
- **Rollen:** Viewer in Backend + Frontend
- **memberOf:** `CN=App-Users,OU=Groups,OU=ITM,OU=Bereiche,DC=muenchen,DC=de`

#### Max Dienstleister (`ext.dienstleister`)
- **Email:** dienstleister@external-company.de
- **Password:** `Demo123!Ext` (temporary)
- **Department:** Externe Dienstleister
- **Telefon:** +49 89 999-99999
- **Rollen:** Nur Viewer in Backend
- **lhmObjectID:** 999999999 (Custom für externe User)
- **memberOf:** `CN=External-Contractors,OU=External,DC=muenchen,DC=de`

## Deployment

### Voraussetzungen

```powershell
# 1. Terraform Credentials setzen (verwende secure Version!)
. .\set-terraform-credentials-secure.ps1

# 2. Keycloak Admin Credentials bereitstellen
$env:KC_CLIENT_SECRET = "YOUR_ADMIN_CLIENT_SECRET"
```

### Apply

```powershell
cd Terraform

# Plan erstellen
python run_terraform.py --env local --action plan --client-secret $env:KC_CLIENT_SECRET

# Apply durchführen
python run_terraform.py --env local --action apply --client-secret $env:KC_CLIENT_SECRET
```

### Outputs anzeigen

```powershell
# Alle Outputs
terraform -chdir=environments/local output

# Sensitive Outputs (Client Secrets, User Credentials)
terraform -chdir=environments/local output lhm_demo_clients
terraform -chdir=environments/local output lhm_demo_users
terraform -chdir=environments/local output lhm_demo_test_info
```

## Testing

### 1. Client Credentials Grant (Backend Client)

```powershell
$tokenEndpoint = "https://ssolocalhost.muenchen.de:8080/auth/realms/LHM-Demo/protocol/openid-connect/token"
$clientId = "lhm-demo-backend"
$clientSecret = "YOUR_CLIENT_SECRET_FROM_OUTPUT"

$response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $clientId
    client_secret = $clientSecret
    scope = "profile email lhm-core roles"
}

$response.access_token
```

### 2. Resource Owner Password Grant (User Login)

```powershell
$response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body @{
    grant_type = "password"
    client_id = $clientId
    client_secret = $clientSecret
    username = "maria.admin"
    password = "YOUR_NEW_PASSWORD"  # Nach Passwort-Änderung
    scope = "profile email lhm-core roles"
}

$response.access_token
```

### 3. Authorization Code Flow (Public Client)

Öffne im Browser:
```
https://ssolocalhost.muenchen.de:8080/auth/realms/LHM-Demo/protocol/openid-connect/auth?client_id=lhm-demo-frontend&redirect_uri=http://localhost:3000/callback&response_type=code&scope=openid%20profile%20email%20lhm-core%20roles&code_challenge=YOUR_PKCE_CHALLENGE&code_challenge_method=S256
```

### 4. Token dekodieren (JWT Payload anzeigen)

```powershell
# PowerShell JWT Decoder
function Decode-JWT {
    param($token)
    $parts = $token.Split('.')
    $payload = $parts[1]
    
    # Base64Url -> Base64
    $payload = $payload.Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
    }
    
    $bytes = [Convert]::FromBase64String($payload)
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    $json | ConvertFrom-Json | ConvertTo-Json -Depth 10
}

Decode-JWT -token $response.access_token
```

## Wichtige Outputs

Nach dem Apply werden folgende Informationen ausgegeben:

### `lhm_demo_realm_info`
- Realm ID
- Realm Name
- Display Name
- Login Theme

### `lhm_demo_clients` (sensitive)
- Confidential Client ID + Secret
- Public Client ID
- Rollen für beide Clients

### `lhm_demo_users` (sensitive)
- Usernamen, E-Mails, Passwörter
- lhmObjectID, LDAP Entry DN

### `lhm_demo_test_info` (sensitive)
- Keycloak URLs (Token Endpoint, Auth Endpoint)
- Curl-Beispielbefehle für Tests

## Cleanup

```powershell
# Komplettes Demo-Setup entfernen
python run_terraform.py --env local --action destroy --client-secret $env:KC_CLIENT_SECRET

# Nur bestimmte Ressourcen entfernen
terraform -chdir=environments/local destroy -target=module.demo_user_external
```

## Troubleshooting

### "Theme not found"
Die LHM-Themes müssen in Keycloak installiert sein:
- `lhm-default.v2` - Login Theme
- Falls nicht vorhanden, verwende `keycloak` als Fallback

### "Client scope 'lhm-core' not found"
Das `realm-scopes` Modul muss zuerst erfolgreich applyed werden:
```powershell
terraform -chdir=environments/local apply -target=module.lhm_demo_scopes
```

### "User password must be changed"
Alle Demo-User haben temporäre Passwörter und müssen diese bei erster Anmeldung ändern.
Für Tests können Sie `temporary_password = false` im Modul setzen.

### "Composite role not found"
Die Basis-Rollen müssen vor den Composite-Rollen existieren.
Dies wird durch `depends_on` im Modul gesteuert.

## Sicherheitshinweise

⚠️ **Produktionsumgebung:**
- Verwenden Sie **niemals** die Demo-Passwörter in Produktion
- Generieren Sie starke Client Secrets
- Aktivieren Sie MFA für Admin-Accounts
- Verwenden Sie Realm-specific Token Lifespans
- Implementieren Sie Brute Force Protection
- Aktivieren Sie Audit Logging

⚠️ **Credentials Management:**
- Client Secrets gehören **NICHT** in Git
- Verwenden Sie Secret Management Tools (HashiCorp Vault, Azure Key Vault)
- Rotieren Sie Secrets regelmäßig
- Nutzen Sie `terraform output` nur lokal, nie in CI/CD Logs

## Module Dependencies

Dieses Setup verwendet folgende Module:

1. **realm-scopes** (`../../modules/realm-scopes`)
   - Erstellt LHM Standard Scopes
   - Managed `roles` Scope mit `include.in.token.scope=true`

2. **oidc-client** (`../../modules/oidc-client`)
   - Erstellt OIDC Clients (Confidential/Public)
   - Managed Client Roles mit Composite Support

3. **keycloak-user** (`../../modules/keycloak-user`)
   - Erstellt Benutzer mit LHM-Attributen
   - Generiert lhmObjectID, LDAP Entry DN
   - Unterstützt memberOf, department, telephoneNumber

## Weitere Informationen

- [Keycloak Provider Dokumentation](https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [RFC 6749 - OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc6749)
- [LHM SSO Dokumentation](https://confluence.muenchen.de/sso)
