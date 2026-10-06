# saml-client-encrypted

Opinionated Template fuer einen **SAML Service Provider mit signierten und
verschluesselten Assertions/Dokumenten und Client Signature Required** gemaess
[docs/saml-integration.md](https://git.muenchen.de/directory-services/idp/-/blob/main/docs/saml-integration.md)
("Signatur- und Verschluesselungs-Konfiguration") und
[ADR-004](../../../docs/decisions/ADR-004-saml-client-templates.md).

Kapselt [`modules/saml-client`](../saml-client/) und verdrahtet alle
sicherheitsrelevanten Pflichteinstellungen fuer dieses Sicherheitsprofil fest.

## Wann verwenden?

- Wie [`saml-client-signed-requests`](../saml-client-signed-requests/),
  zusaetzlich verschluesselt der IdP die Assertion mit dem oeffentlichen
  Verschluesselungszertifikat des SP.
- Gemaess docs/saml-integration.md insbesondere dann sinnvoll, wenn neben der
  Authentifizierung zusaetzlich eine **Autorisierung anhand von Rollen**
  (Attribut `Role`) konfiguriert wird - z.B. bei SaaS-/Cloud-Anwendungen
  ausserhalb des LHM-Netzes, deren Rollen-/Berechtigungsinformationen
  zusaetzlich geschuetzt werden sollen.

## Fest verdrahtete Einstellungen

| Einstellung | Wert | Grund |
| --- | --- | --- |
| `sign_documents` | `true` | Response (Dokument) wird vom IdP signiert |
| `sign_assertions` | `true` | Assertion wird signiert (IDP-seitig Pflicht) |
| `client_signature_required` | `true` | IdP prueft signierte Requests des SP |
| `encrypt_assertions` | `true` | Assertion wird mit dem SP-Zertifikat verschluesselt |
| `signature_algorithm` | `RSA_SHA256` | Empfohlener Signaturalgorithmus |
| `include_authn_statement` | `true` | `AuthnStatement` in der Response enthalten |
| `full_scope_allowed` | `false` | Keine impliziten Rollen-/Audience-Mappings |

Diese Werte sind **nicht** ueber Variablen veraenderbar. Wird keine
Verschluesselung benoetigt, `saml-client-signed-requests` verwenden.

> **Achtung:** Verschluesselungszertifikate (aus der LHM-PKI) haben laut
> docs/saml-integration.md eine Laufzeit von 1-3 Jahren und muessen
> rechtzeitig rotiert werden. Ein Ablauf ohne Erneuerung fuehrt zum Ausfall
> der SSO-Anbindung.

## Beispiel

```hcl
module "my_app_saml" {
  source = "../../modules/saml-client-encrypted"

  realm_id    = keycloak_realm.my_realm.id
  client_id   = "https://my-app.muenchen.de/saml/metadata"
  name        = "My App (SAML)"
  description = "SAML Service Provider fuer My App"

  valid_redirect_uris = ["https://my-app.muenchen.de/saml/acs"]

  logout_service_post_binding_url = "https://my-app.muenchen.de/saml/slo"

  # Oeffentliche SP-Zertifikate (PEM, ohne "-----BEGIN/END CERTIFICATE-----")
  signing_certificate    = var.my_app_saml_signing_certificate
  encryption_certificate = var.my_app_saml_encryption_certificate

  saml_attribute_mappers = {
    "lhmObjectID" = {
      user_attribute      = "lhmObjectID"
      saml_attribute_name = "lhmObjectID"
    }
  }
}
```

## Variablen

| Variable | Typ | Default | Beschreibung |
| --- | --- | --- | --- |
| `realm_id` | `string` | - | Keycloak Realm ID |
| `client_id` | `string` | - | SAML Entity ID des Service Providers |
| `name` | `string` | - | Anzeigename |
| `description` | `string` | `""` | Beschreibung |
| `enabled` | `bool` | `true` | Client aktiviert |
| `root_url` | `string` | `""` | Root URL |
| `base_url` | `string` | `""` | Base URL (Default Endpoint) |
| `valid_redirect_uris` | `list(string)` | - (Pflicht, mind. 1 Eintrag) | Assertion Consumer Service (ACS) URLs |
| `assertion_consumer_post_url` | `string` | `null` | ACS URL fuer POST Binding (falls abweichend von `valid_redirect_uris`) |
| `assertion_consumer_redirect_url` | `string` | `null` | ACS URL fuer Redirect Binding |
| `logout_service_post_binding_url` | `string` | `null` | Single Logout URL fuer POST Binding |
| `logout_service_redirect_binding_url` | `string` | `null` | Single Logout URL fuer Redirect Binding |
| `name_id_format` | `string` | `"persistent"` | Format des `NameID` (siehe docs/saml-integration.md) |
| `force_name_id_format` | `bool` | `false` | Angefragtes NameID-Format des SP ignorieren |
| `force_post_binding` | `bool` | `true` | SAML POST Binding erzwingen |
| `front_channel_logout` | `bool` | `true` | Front-Channel statt Back-Channel Logout |
| `idp_initiated_sso_url_name` | `string` | `null` | URL-Alias fuer IdP-initiated SSO |
| `idp_initiated_sso_relay_state` | `string` | `null` | Relay State fuer IdP-initiated SSO |
| `signing_certificate` | `string` | - (Pflicht) | Oeffentliches SP-Zertifikat (PEM, ohne Header/Footer) zur Pruefung signierter Requests |
| `encryption_certificate` | `string` | - (Pflicht) | Oeffentliches SP-Zertifikat (PEM, ohne Header/Footer) zur Assertion-Verschluesselung |
| `encryption_algorithm` | `string` | Provider-Default | Symmetrischer Algorithmus zur Assertion-Verschluesselung (z.B. `AES_128_GCM`, `AES_256_GCM`) |
| `encryption_key_algorithm` | `string` | Provider-Default (`RSA-OAEP-11`) | Algorithmus zur Verschluesselung des symmetrischen Schluessels |
| `encryption_digest_method` | `string` | Provider-Default (`SHA-256`) | Digest-Methode fuer die Schluesselverschluesselung |
| `encryption_mask_generation_function` | `string` | Provider-Default (`mgf1sha256`) | Mask Generation Function fuer RSA-OAEP |
| `roles` | `map(object)` | `{}` | Client Roles inkl. Composite-Rollen |
| `saml_attribute_mappers` | `map(object)` | `{}` | User Attribute Mapper (Keycloak-Attribut -> SAML-Attribut im `AttributeStatement`) |
| `extra_attributes` | `map(string)` | `{}` | Zusaetzliche Client-Attribute |
| `ad_app_identifier` | `string` | `null` | AD-App-Bezeichner fuer die AD-Provisionierung (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen; mappt auf Client-Attribut `lhm.ad.app.identifier` |
| `contact_emails` | `list(string)` | `[]` | Ansprechpartner-E-Mail-Adressen (komma-separiert im Client-Attribut `lhm.app.contact.emails`); ersetzt die Praxis, E-Mails in `description`/`name` zu hinterlegen |

## Outputs

| Output | Beschreibung |
| --- | --- |
| `client_id` | Interne Keycloak Client ID (UUID) |
| `client_roles` | Map der erstellten Client-Rollen |
