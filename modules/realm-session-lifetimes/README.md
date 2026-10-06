# realm-session-lifetimes

Berechnet Realm-weite **Token- und Session-Lebensdauern** nach der
IDP-Best-Practice-Empfehlung ("Token- & Session-Lebensdauern", siehe
[docs/oidc-integration.md](https://git.muenchen.de/directory-services/idp/-/blob/main/docs/oidc-integration.md)
im idp-Repo) - mit der Möglichkeit, einzelne Werte pro Realm gezielt zu
überschreiben.

## Zwei Betriebsmodi

Token-/Session-Lebensdauern sind Top-Level-Attribute der Ressource
`keycloak_realm` selbst (z.B. `sso_session_idle_timeout`,
`access_token_lifespan`) - der Keycloak-Provider bietet dafür keine eigene
Sub-Ressource. Je nachdem, ob ein Realm bereits eine eigene
`keycloak_realm`-Ressource hat oder nicht, gibt es zwei Wege, die Werte
anzuwenden:

1. **Realm hat bereits eine eigene `keycloak_realm`-Ressource** (z.B.
   `ciam-dev-realm.tf`, per Terraform neu angelegte Realms): Das Modul legt
   dafür **keine** eigene Ressource an - es berechnet nur die **aufgelösten
   Werte** (Default oder Override) pro Realm als Map-Output
   (`local.settings`); die bestehende `keycloak_realm`-Ressource verdrahtet
   die zehn Attribute direkt aus diesem Output (siehe "Verwendung" unten).
   Eine zweite, konkurrierende Ressource für denselben Realm wäre hier ein
   Fehler.
2. **Vor-Terraform-Realm ohne eigene `keycloak_realm`-Ressource** (z.B.
   `IBS53` - der Realm existiert in Keycloak, aber Terraform verwaltet
   bislang nur Scopes/Clients dafür über den literalen Realm-Namen, siehe
   `ibs53-clients.tf`): Für solche Realms in `var.owned_realm_id` legt das
   Modul selbst eine **schmal geschnittene** `keycloak_realm`-Ressource an -
   analog zu `modules/realm-themes`. Nur die zehn Session-Felder werden
   gesetzt, alles andere (Themes, Password Policy, SSL, Flows, SMTP, ...)
   ist per `lifecycle.ignore_changes` geschützt, damit kein anderswo bereits
   konfiguriertes Realm-Attribut überschrieben wird. Diese Ressource **muss
   vor dem ersten Apply importiert werden** (der Realm existiert ja bereits) -
   `run_terraform.py` liest `owned_realm_id` aus dem Modul-Block und schreibt
   dafür automatisch einen `import`-Block in `imports.auto.tf`, analog zum
   bestehenden Mechanismus für `modules/realm-themes`.

Siehe [ADR-006](../../../docs/decisions/ADR-006-realm-session-lifetimes.md)
für die vollständige Begründung dieser zwei Modi.

## Verwendung

```hcl
module "realm_session_lifetimes" {
  source = "../../modules/realm-session-lifetimes"

  realm_id = ["ciam-dev", "wahl-dev"]

  # Optional: realm-spezifische Ausnahmen von den globalen Defaults
  session_lifetime_overrides = {
    "wahl-dev" = {
      sso_session_idle_timeout = "1h"
    }
  }
}

resource "keycloak_realm" "ciam_dev" {
  realm = "ciam-dev"
  # ...

  sso_session_idle_timeout             = module.realm_session_lifetimes.settings["ciam-dev"].sso_session_idle_timeout
  sso_session_max_lifespan             = module.realm_session_lifetimes.settings["ciam-dev"].sso_session_max_lifespan
  revoke_refresh_token                 = module.realm_session_lifetimes.settings["ciam-dev"].revoke_refresh_token
  refresh_token_max_reuse              = module.realm_session_lifetimes.settings["ciam-dev"].refresh_token_max_reuse
  access_token_lifespan                = module.realm_session_lifetimes.settings["ciam-dev"].access_token_lifespan
  offline_session_idle_timeout         = module.realm_session_lifetimes.settings["ciam-dev"].offline_session_idle_timeout
  offline_session_max_lifespan_enabled = module.realm_session_lifetimes.settings["ciam-dev"].offline_session_max_lifespan_enabled
  offline_session_max_lifespan         = module.realm_session_lifetimes.settings["ciam-dev"].offline_session_max_lifespan
  access_code_lifespan_login           = module.realm_session_lifetimes.settings["ciam-dev"].access_code_lifespan_login
  access_code_lifespan_user_action     = module.realm_session_lifetimes.settings["ciam-dev"].access_code_lifespan_user_action
}
```

### Vor-Terraform-Realm ohne eigene keycloak_realm-Ressource (z.B. IBS53)

```hcl
module "realm_session_lifetimes" {
  source = "../../modules/realm-session-lifetimes"

  realm_id = ["ciam-predev", "wahl-predev", "IBS53"]

  # IBS53 hat keine eigene keycloak_realm-Ressource - das Modul legt selbst
  # eine schmal geschnittene Ressource dafür an (nur die 10 Session-Felder).
  owned_realm_id = ["IBS53"]
}
```

`terraform plan`/`apply` (CI) importiert `module.realm_session_lifetimes.keycloak_realm.managed["IBS53"]`
automatisch über einen von `run_terraform.py` generierten `import`-Block,
bevor die Ressource zum ersten Mal angewendet wird.

## Globale Defaults (Best Practice Empfehlung)

| Parameter | Variable | Default |
| --- | --- | --- |
| SSO Session Idle Timeout | `sso_session_idle_timeout` | `30m` |
| SSO Session Max | `sso_session_max_lifespan` | `10h` |
| Revoke Refresh Token (Rotation) | `revoke_refresh_token` | `true` |
| Refresh Token Max Reuse | `refresh_token_max_reuse` | `0` (Single-Use) |
| Access Token Lifespan | `access_token_lifespan` | `5m` |
| Offline Session Idle | `offline_session_idle_timeout` | `168h` (7 Tage) |
| Offline Session Max Limited | `offline_session_max_lifespan_enabled` | `true` |
| Offline Session Max | `offline_session_max_lifespan` | `720h` (30 Tage) |
| Login Timeout | `access_code_lifespan_login` | `30m` |
| Login Action Timeout | `access_code_lifespan_user_action` | `5m` |

Alle Werte für den Keycloak-Provider sind **Go-Duration-Strings** (Einheiten
`s`/`m`/`h` - **kein** `d` für Tage, daher z.B. `168h` statt `7d`).

Die Defaults selbst sind über die gleichnamigen Modul-Variablen anpassbar
(z.B. um sie IDP-weit in einer neuen Ankündigungsrunde zu verschärfen), das
ist aber ein separater Vorgang von den **realm-spezifischen** Overrides.

## Realm-spezifische Overrides

Über `session_lifetime_overrides` (Map, Key = Realm-ID) können einzelne
Realms gezielt von den globalen Defaults abweichen. Es müssen nur die
Felder angegeben werden, die abweichen sollen - alle anderen Felder bleiben
beim globalen Default:

```hcl
session_lifetime_overrides = {
  "ciam-predev" = {
    sso_session_idle_timeout = "1h"
    access_token_lifespan    = "10m"
  }
}
```

## Variablen

| Variable | Typ | Default | Beschreibung |
| --- | --- | --- | --- |
| `realm_id` | `list(string)` | - | Realms, für die Settings berechnet werden |
| `owned_realm_id` | `list(string)` | `[]` | Teilmenge von `realm_id`: Realms ohne eigene `keycloak_realm`-Ressource anderswo, für die das Modul selbst eine schmal geschnittene Ressource anlegt (Import vor erstem Apply nötig) |
| `sso_session_idle_timeout` | `string` | `"30m"` | Globaler Default |
| `sso_session_max_lifespan` | `string` | `"10h"` | Globaler Default |
| `revoke_refresh_token` | `bool` | `true` | Globaler Default |
| `refresh_token_max_reuse` | `number` | `0` | Globaler Default |
| `access_token_lifespan` | `string` | `"5m"` | Globaler Default |
| `offline_session_idle_timeout` | `string` | `"168h"` | Globaler Default |
| `offline_session_max_lifespan_enabled` | `bool` | `true` | Globaler Default |
| `offline_session_max_lifespan` | `string` | `"720h"` | Globaler Default |
| `access_code_lifespan_login` | `string` | `"30m"` | Globaler Default |
| `access_code_lifespan_user_action` | `string` | `"5m"` | Globaler Default |
| `session_lifetime_overrides` | `map(object)` | `{}` | Realm-spezifische Overrides, siehe oben |

## Outputs

| Output | Beschreibung |
| --- | --- |
| `settings` | Map Realm-ID -> aufgelöste Token-/Session-Lebensdauern (Default oder Override) |
