# oidc-client-webapp

Opinionated Template fuer **Server-Anwendung mit User-Login** gemaess
[docs/oidc-integration.md](https://git.muenchen.de/directory-services/idp/-/blob/main/docs/oidc-integration.md) ("Client-Typen") und
[ADR-003](../../../docs/decisions/ADR-003-oidc-client-templates.md).

Kapselt [`modules/oidc-client`](../oidc-client/) und verdrahtet alle
sicherheitsrelevanten Pflichteinstellungen fuer diesen Client-Typ fest.

## Wann verwenden?

- Klassische Server-/Backend-Anwendungen mit eigener User-Session
- Das Backend laeuft auf einem Server und kann ein Client Secret sicher
  verwahren (Umgebungsvariable / Secrets Manager)
- Der Authorization Code Flow findet vollstaendig server-seitig statt

## Fest verdrahtete Einstellungen

| Einstellung | Wert | Grund |
| --- | --- | --- |
| `client_authenticator_type` | `client-secret` (Confidential Client) | Server kann Secret sicher verwahren |
| `standard_flow_enabled` | `true` | Authorization Code Flow |
| `implicit_flow_enabled` | `false` | Implicit Flow ist veraltet/unsicher |
| `direct_access_grants_enabled` | `false` | Kein Resource Owner Password Flow |
| `service_accounts_enabled` | `false` | Kein M2M-Flow auf diesem Client (siehe `oidc-client-m2m`) |
| `full_scope_allowed` | `false` | Keine impliziten Rollen-/Audience-Mappings |

Diese Werte sind **nicht** ueber Variablen veraenderbar. Wird zusaetzlich ein
M2M-Zugriff (Client Credentials) fuer dieselbe Anwendung benoetigt, dafuer
einen separaten Client mit `oidc-client-m2m` anlegen oder bei begruendetem
Bedarf `modules/oidc-client` direkt verwenden.

## Beispiel

```hcl
module "my_app_backend" {
  source = "../../modules/oidc-client-webapp"

  realm_id    = keycloak_realm.my_realm.id
  client_id   = "my-app-backend"
  name        = "My App Backend"
  description = "Confidential OIDC Client fuer das Backend von My App"

  root_url            = "https://my-app.muenchen.de"
  valid_redirect_uris = ["https://my-app.muenchen.de/login/oauth2/code/*"]

  roles = {
    "viewer" = { description = "Lesender Zugriff" }
    "admin"  = { description = "Administrativer Zugriff" }
  }
}
```

Das generierte `client_secret` ist als Output `sensitive` markiert und sollte
ueber Terraform-Outputs/State **nicht** im Klartext weiterverteilt werden -
stattdessen z.B. direkt in einen Secrets Manager schreiben oder per
`client_secret`-Variable ein extern verwaltetes Secret (GitLab CI/CD Variable)
uebergeben.

## Variablen

| Variable | Typ | Default | Beschreibung |
| --- | --- | --- | --- |
| `realm_id` | `string` | - | Keycloak Realm ID |
| `client_id` | `string` | - | OAuth2 `client_id` |
| `name` | `string` | - | Anzeigename |
| `description` | `string` | `""` | Beschreibung |
| `enabled` | `bool` | `true` | Client aktiviert |
| `root_url` | `string` | `""` | Root URL |
| `base_url` | `string` | `""` | Default Redirect Path |
| `admin_url` | `string` | `""` | Admin URL (z.B. Backchannel Logout) |
| `valid_redirect_uris` | `list(string)` | - (Pflicht, mind. 1 Eintrag) | Erlaubte Redirect URIs |
| `web_origins` | `list(string)` | `[]` | Erlaubte CORS Origins |
| `client_secret` | `string` | `null` (auto-generiert) | Festes Client Secret |
| `default_client_scopes` | `list(string)` | `[]` | Default Client Scopes; leer = Realm-Defaults (modules/realm-scopes) bleiben unveraendert |
| `optional_client_scopes` | `list(string)` | `[]` | Optional Client Scopes; leer = Realm-Defaults (modules/realm-scopes) bleiben unveraendert |
| `roles` | `map(object)` | `{}` | Client Roles inkl. Composite-Rollen |
| `extra_attributes` | `map(string)` | `{}` | Zusaetzliche Client-Attribute |
| `ad_app_identifier` | `string` | `null` | AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen; mappt auf Client-Attribut `lhm.ad.app.identifier` |
| `contact_emails` | `list(string)` | `[]` | Ansprechpartner-E-Mail-Adressen (komma-separiert im Client-Attribut `lhm.app.contact.emails`); ersetzt die Praxis, E-Mails in `description`/`name` zu hinterlegen |

## Outputs

| Output | Beschreibung |
| --- | --- |
| `client_id` | Interne Keycloak Client ID (UUID) |
| `client_secret` | Client Secret (sensitive) |
| `client_roles` | Map der erstellten Client-Rollen |
