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
