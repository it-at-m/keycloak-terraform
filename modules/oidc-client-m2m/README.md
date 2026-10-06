# oidc-client-m2m

Opinionated Template fuer **Dienst-zu-Dienst-Kommunikation (M2M)** gemaess
[docs/oidc-integration.md](https://git.muenchen.de/directory-services/idp/-/blob/main/docs/oidc-integration.md) ("Client-Typen") und
[ADR-003](../../../docs/decisions/ADR-003-oidc-client-templates.md).

Kapselt [`modules/oidc-client`](../oidc-client/) und verdrahtet alle
sicherheitsrelevanten Pflichteinstellungen fuer diesen Client-Typ fest.

## Wann verwenden?

- Maschine-zu-Maschine-Kommunikation (Hintergrundjobs, Microservices)
- **Kein** Benutzer beteiligt - kein Redirect, keine Login-Seite, keine User-Session
- Die Anwendung authentifiziert sich direkt mit `client_id` + `client_secret`

## Fest verdrahtete Einstellungen

| Einstellung | Wert | Grund |
| --- | --- | --- |
| `client_authenticator_type` | `client-secret` (Confidential Client) | Authentifizierung per Client Secret |
| `standard_flow_enabled` | `false` | Kein User-Login |
| `implicit_flow_enabled` | `false` | Kein User-Login |
| `direct_access_grants_enabled` | `false` | Kein Resource Owner Password Flow |
| `service_accounts_enabled` | `true` | Client Credentials Flow |
| `full_scope_allowed` | `false` | Keine impliziten Rollen-/Audience-Mappings |
| `valid_redirect_uris` / `web_origins` | `[]` | Kein Redirect bei M2M |

Diese Werte sind **nicht** ueber Variablen veraenderbar. Wird zusaetzlich ein
User-Login fuer dieselbe Anwendung benoetigt, dafuer einen separaten Client
mit `oidc-client-webapp` anlegen.

## Service Account Rollen

M2M-Clients rufen i.d.R. eine andere API mit eingeschraenkten Berechtigungen
auf. Ueber `service_account_roles` werden dem Service-Account gezielt
Client-Rollen anderer Clients zugewiesen (z.B. `realm-management` fuer einen
IAM-Sync-Client):

```hcl
module "iam_sync_client" {
  source = "../../modules/oidc-client-m2m"

  realm_id    = keycloak_realm.my_realm.id
  client_id   = "iam-sync"
  name        = "IAM Sync Service"
  description = "M2M Client fuer den nightly IAM-Sync-Job"

  service_account_roles = [
    { client_id = "realm-management", role = "manage-users" },
    { client_id = "realm-management", role = "view-users" },
    { client_id = "realm-management", role = "query-groups" },
  ]
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
| `client_secret` | `string` | `null` (auto-generiert) | Festes Client Secret |
| `default_client_scopes` | `list(string)` | `[]` | Immer im Token enthalten |
| `optional_client_scopes` | `list(string)` | `[]` | Muessen per `scope`-Parameter angefragt werden |
| `roles` | `map(object)` | `{}` | Client Roles, die dieser Client anderen Service-Accounts anbietet |
| `service_account_roles` | `list(object)` | `[]` | Rollen anderer Clients, die dem eigenen Service-Account zugewiesen werden |
| `extra_attributes` | `map(string)` | `{}` | Zusaetzliche Client-Attribute |
| `ad_app_identifier` | `string` | `null` | AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen; mappt auf Client-Attribut `lhm.ad.app.identifier` |
| `contact_emails` | `list(string)` | `[]` | Ansprechpartner-E-Mail-Adressen (komma-separiert im Client-Attribut `lhm.app.contact.emails`); ersetzt die Praxis, E-Mails in `description`/`name` zu hinterlegen |

## Outputs

| Output | Beschreibung |
| --- | --- |
| `client_id` | Interne Keycloak Client ID (UUID) |
| `client_secret` | Client Secret (sensitive) |
| `client_roles` | Map der erstellten Client-Rollen |
| `service_account_user_id` | User ID des Service-Accounts |
