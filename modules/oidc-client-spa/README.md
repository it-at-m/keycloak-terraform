# oidc-client-spa

Opinionated Template fuer **SPA / Mobile App mit User-Login** gemaess
[docs/oidc-integration.md](https://git.muenchen.de/directory-services/idp/-/blob/main/docs/oidc-integration.md) ("Client-Typen") und
[ADR-003](../../../docs/decisions/ADR-003-oidc-client-templates.md).

Kapselt [`modules/oidc-client`](../oidc-client/) und verdrahtet alle
sicherheitsrelevanten Pflichteinstellungen fuer diesen Client-Typ fest.

## Wann verwenden?

- Browser-basierte Single Page Applications (SPA)
- Mobile Apps mit interaktivem User-Login
- Immer dann, wenn **kein** Client Secret sicher verwahrt werden kann

## Fest verdrahtete Einstellungen

| Einstellung | Wert | Grund |
| --- | --- | --- |
| `client_authenticator_type` | `none` (Public Client) | Kein Client Secret im Frontend |
| `standard_flow_enabled` | `true` | Authorization Code Flow |
| `implicit_flow_enabled` | `false` | Implicit Flow ist veraltet/unsicher |
| `direct_access_grants_enabled` | `false` | Kein Resource Owner Password Flow |
| `service_accounts_enabled` | `false` | Kein M2M-Flow auf diesem Client |
| `full_scope_allowed` | `false` | Keine impliziten Rollen-/Audience-Mappings |
| `pkce_code_challenge_method` | `S256` | PKCE verpflichtend (Schutz ohne Client Secret) |

Diese Werte sind **nicht** ueber Variablen veraenderbar. Wird ein anderer Flow
benoetigt, ist das kein "SPA"-Client mehr - dann `modules/oidc-client` direkt
verwenden.

## Beispiel

```hcl
module "my_app_frontend" {
  source = "../../modules/oidc-client-spa"

  realm_id    = keycloak_realm.my_realm.id
  client_id   = "my-app-frontend"
  name        = "My App Frontend"
  description = "Public OIDC Client fuer die SPA von My App"

  root_url            = "https://my-app.muenchen.de"
  valid_redirect_uris = ["https://my-app.muenchen.de/*", "http://localhost:5173/*"]
  web_origins         = ["https://my-app.muenchen.de", "http://localhost:5173"]

  roles = {
    "viewer" = { description = "Lesender Zugriff" }
    "admin"  = { description = "Administrativer Zugriff" }
  }
}
```

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
| `valid_redirect_uris` | `list(string)` | - (Pflicht, mind. 1 Eintrag) | Erlaubte Redirect URIs |
| `web_origins` | `list(string)` | `["+"]` | Erlaubte CORS Origins |
| `default_client_scopes` | `list(string)` | `[]` | Default Client Scopes; leer = Realm-Defaults (modules/realm-scopes) bleiben unveraendert |
| `optional_client_scopes` | `list(string)` | `[]` | Optional Client Scopes; leer = Realm-Defaults (modules/realm-scopes) bleiben unveraendert |
| `roles` | `map(object)` | `{}` | Client Roles inkl. Composite-Rollen |
| `extra_attributes` | `map(string)` | `{}` | Zusaetzliche Client-Attribute (PKCE bleibt als Top-Level-Attribut erzwungen) |
| `ad_app_identifier` | `string` | `null` | AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen; mappt auf Client-Attribut `lhm.ad.app.identifier` |
| `contact_emails` | `list(string)` | `[]` | Ansprechpartner-E-Mail-Adressen (komma-separiert im Client-Attribut `lhm.app.contact.emails`); ersetzt die Praxis, E-Mails in `description`/`name` zu hinterlegen |

## Outputs

| Output | Beschreibung |
| --- | --- |
| `client_id` | Interne Keycloak Client ID (UUID) |
| `client_roles` | Map der erstellten Client-Rollen |
