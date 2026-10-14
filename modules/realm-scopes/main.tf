terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

# Filter realms based on blacklist
# WICHTIG (Incident Maerz 2026): Die for_each-Schluessel aller Ressourcen
# sind die Realm-Namen. Bei leeren Steuer-Variablen (realm_blacklist,
# bootstrap_realm_ids) MUESSEN enabled_realm_ids/settled_realm_ids exakt
# var.realm_id ergeben - sonst plant Terraform Destroys, die die Scopes
# real in Keycloak (und aus allen Clients) loeschen.
locals {
  enabled_realm_ids = [for r in var.realm_id : r if !contains(var.realm_blacklist, r)]

  # Realms, die bereits in Keycloak existieren - Bootstrap-Realms (werden im
  # selben Apply erst von Terraform angelegt) sind hier ausgenommen, weil
  # fuer sie keine bereits existierenden Keycloak-Objekte (Built-in-Scopes,
  # auto-erstellter roles-Scope, phone-Mapper) vorausgesetzt werden koennen.
  settled_realm_ids = [for r in local.enabled_realm_ids : r if !contains(var.bootstrap_realm_ids, r)]

  # Empty list if skipping lookups, otherwise settled realms
  realms_for_lookup = var.skip_default_scopes_lookup ? [] : local.settled_realm_ids

  # Protocol Mapper Overrides - Ermittelt realm-spezifische Attribute oder Default-Werte
  lhmObjectID_attributes = {
    for realm in local.enabled_realm_ids : realm => try(
      var.protocol_mapper_overrides[realm].lhmObjectID_user_attribute,
      "lhmObjectID" # Default-Wert wenn realm nicht in overrides oder Attribut null
    )
  }
}

resource "keycloak_openid_client_scope" "common_client_scope" {
  for_each = toset(local.enabled_realm_ids)
  # lookup statt each.key: erzeugt fuer Bootstrap-Realms die Apply-Reihenfolge
  # Realm-vor-Scope (sonst 404-Race beim ersten Apply); fuer alle anderen
  # Realms identischer Wert -> kein Diff. Alle Mapper/Zuordnungen haengen an
  # den Scope-Ressourcen und erben die Reihenfolge.
  realm_id               = lookup(var.bootstrap_realm_refs, each.key, each.key)
  name                   = "lhm-core"
  description            = "LHM standard scope – Contains all user attributes typical for City of Munich applications."
  include_in_token_scope = true
}

# Roles Client Scope - Conditional: Resource oder Data Source
# The roles scope already exists in new realms, but must be created in old ones.
# Bootstrap-Realms ausgenommen: Keycloak legt "roles" beim Realm-Anlegen
# automatisch an - ein Create im selben Apply liefe auf einen 409 Conflict;
# der Scope wird im naechsten Lauf per Discovery importiert (run_terraform.py 4a1).
resource "keycloak_openid_client_scope" "roles_scope" {
  for_each = var.manage_roles_scope ? toset(local.settled_realm_ids) : []

  realm_id               = each.key
  name                   = "roles"
  description            = "OpenID Connect scope for add user roles to the access token"
  include_in_token_scope = true

  lifecycle {
    ignore_changes = [name]
  }
}

data "keycloak_openid_client_scope" "roles_scope_existing" {
  for_each = var.manage_roles_scope ? [] : toset(local.realms_for_lookup)

  realm_id = each.key
  name     = "roles"
}

# Unified local variable for roles scope ID
locals {
  roles_scope_ids = var.manage_roles_scope ? {
    for k, v in keycloak_openid_client_scope.roles_scope : k => v.id
    } : {
    for k, v in data.keycloak_openid_client_scope.roles_scope_existing : k => v.id
  }
}

# Data sources for built-in Keycloak scopes (with error handling)
data "keycloak_openid_client_scope" "profile" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "profile"

  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Client scope 'profile' not found in realm ${each.key}. Please create it manually or use --refresh."
    }
  }
}

data "keycloak_openid_client_scope" "email" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "email"

  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Client scope 'email' not found in realm ${each.key}. Please create it manually or use --refresh."
    }
  }
}

data "keycloak_openid_client_scope" "phone" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "phone"

  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Client scope 'phone' not found in realm ${each.key}. Please create it manually or use --refresh."
    }
  }
}

data "keycloak_openid_client_scope" "acr" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "acr"

  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Client scope 'acr' not found in realm ${each.key}. Please create it manually or use --refresh."
    }
  }
}

data "keycloak_openid_client_scope" "basic" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "basic"
}

data "keycloak_openid_client_scope" "web_origins" {
  for_each = toset(local.realms_for_lookup)
  realm_id = each.key
  name     = "web-origins"

  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Client scope 'web-origins' not found in realm ${each.key}. Please create it manually or use --refresh."
    }
  }
}

# ⚠️ DEPRECATED: LHM Scope (Legacy - use lhm-core instead)
resource "keycloak_openid_client_scope" "lhm_scope" {
  for_each = toset(local.enabled_realm_ids)
  # lookup statt each.key: Apply-Reihenfolge fuer Bootstrap-Realms, s.o.
  realm_id               = lookup(var.bootstrap_realm_refs, each.key, each.key)
  name                   = "LHM"
  description            = "⚠️ DEPRECATED: Legacy scope for backward compatibility. Use 'lhm-core' for new applications. This scope will be removed in a future release."
  include_in_token_scope = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_telephone" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "telephoneNumber"
  user_attribute      = "telephoneNumber"
  claim_name          = "telephoneNumber"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_surname" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "surname"
  user_attribute      = "lastName"
  claim_name          = "surname"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_property_protocol_mapper" "lhm_givenname" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "givenname"
  user_property       = "firstName"
  claim_name          = "givenname"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_department" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "department"
  user_attribute      = "department"
  claim_name          = "department"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_display_name" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "displayName"
  user_attribute      = "displayName"
  claim_name          = "displayName"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_object_id" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_openid_client_scope.lhm_scope[each.key].id
  name            = "lhmObjectID"
  # Realm-spezifisches user_attribute via protocol_mapper_overrides Variable (auch für Legacy Scope)
  user_attribute      = local.lhmObjectID_attributes[each.key]
  claim_name          = "lhmObjectID"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_property_protocol_mapper" "lhm_username" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "username"
  user_property       = "Username"
  claim_name          = "username"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

resource "keycloak_openid_user_property_protocol_mapper" "lhm_email" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_scope[each.key].id
  name                = "email"
  user_property       = "email"
  claim_name          = "email"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

# ⚠️ DEPRECATED: LHM_Extended Scope
resource "keycloak_openid_client_scope" "lhm_extended_scope" {
  for_each = toset(local.enabled_realm_ids)
  # lookup statt each.key: Apply-Reihenfolge fuer Bootstrap-Realms, s.o.
  realm_id               = lookup(var.bootstrap_realm_refs, each.key, each.key)
  name                   = "LHM_Extended"
  description            = "⚠️ DEPRECATED: Extended legacy scope for backward compatibility. Use 'lhm-core' for new applications. This scope will be removed in a future release."
  include_in_token_scope = true
}

# 1) dn (LDAP Entry DN) - environment-aware mapping
resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_ext_dn" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name                = "dn"
  user_attribute      = var.attribute_mappings.ldap_entry_dn
  claim_name          = "dn"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

# 2) User Authorities (Custom oder Realm Roles)
resource "keycloak_generic_protocol_mapper" "lhm_ext_authorities" {
  for_each        = var.use_custom_authorities_mapper ? toset(local.enabled_realm_ids) : []
  realm_id        = each.key
  client_scope_id = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name            = "User Authorities mapper"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-authorities-mapper"

  config = {
    "authorities"          = "authorities"
    "claim.name"           = "authorities"
    "id.token.claim"       = "true"
    "jsonType.label"       = "String"
    "multivalued"          = "true"
    "userinfo.token.claim" = "true"
  }
}

resource "keycloak_openid_user_realm_role_protocol_mapper" "lhm_ext_authorities_fallback" {
  for_each        = var.use_custom_authorities_mapper ? [] : toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name            = "User Authorities mapper"

  claim_name          = "authorities"
  claim_value_type    = "String"
  multivalued         = true
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
}

# 3) memberOf
resource "keycloak_openid_user_attribute_protocol_mapper" "lhm_ext_memberof" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name                = "memberof"
  user_attribute      = "memberof"
  claim_name          = "memberof"
  claim_value_type    = "String"
  multivalued         = true
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = false
}

# 4) ACR LoA Level
resource "keycloak_openid_hardcoded_claim_protocol_mapper" "lhm_ext_acr_loa" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name                = "acr loa level"
  claim_name          = "acr"
  claim_value         = "loa-1"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_userinfo     = false
  add_to_access_token = false
}

# 5) Audience Resolve
resource "keycloak_openid_audience_resolve_protocol_mapper" "lhm_ext_audience" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name            = "audience resolve"
}

# 6) Client Roles
resource "keycloak_openid_user_client_role_protocol_mapper" "lhm_ext_client_roles" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.lhm_extended_scope[each.key].id
  name                = "client roles"
  claim_name          = "resource_access.$${client_id}.roles"
  claim_value_type    = "String"
  multivalued         = true
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  lifecycle {
    ignore_changes = [claim_name]
  }
}

# Client Roles Mapper für den roles Scope
# Nur erstellen wenn wir den roles Scope selbst managen
# In existierenden scopes ist der Mapper bereits vorhanden
resource "keycloak_openid_user_client_role_protocol_mapper" "client_roles_mapper" {
  # settled statt enabled: muss dieselben Keys wie roles_scope/roles_scope_ids
  # haben (Bootstrap-Realms haben (noch) keinen verwalteten roles-Scope).
  for_each        = var.manage_roles_scope ? toset(local.settled_realm_ids) : []
  realm_id        = each.key
  client_scope_id = local.roles_scope_ids[each.key]

  name = "client roles"
  // Standard: nur im Access-Token, jetzt auch im UserInfo
  add_to_access_token = true
  add_to_userinfo     = true
  add_to_id_token     = true

  multivalued = true

  // In vielen Keycloak-Defaults wird der Claim-Name dynamisch mit ${client_id} gesetzt:
  // passe das bei Bedarf an den Ist-Zustand an, damit Plan/Drift minimal ist
  claim_name = "resource_access.$${client_id}.roles"

  // Hinweis: Falls der Provider hier ein client_id-Attribut verlangt und der Default-Mapper
  // dynamisch ist, lasse es leer oder entferne die Zeile. Nur setzen, wenn du statisch
  // die Rollen EINES Clients mappen willst.
  // client_id        = ""

  lifecycle {
    // Verhindert unnötige Drifts, falls der bestehende Mapper minimal andere Defaults hat
    ignore_changes = [
      claim_name,
      // client_id, // nur ignorieren, wenn du client_id überhaupt setzt
    ]
  }
}

## lhm-core scope protocol mappers lhmObjectID
resource "keycloak_openid_user_attribute_protocol_mapper" "lhmObjectID" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.common_client_scope[each.key].id
  name                = "lhmObjectID"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  # Realm-spezifisches user_attribute via protocol_mapper_overrides Variable
  user_attribute   = local.lhmObjectID_attributes[each.key]
  claim_value_type = "String"
  claim_name       = "lhmObjectID"
}

## lhm-core scope protocol mappers department
resource "keycloak_openid_user_attribute_protocol_mapper" "department" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.common_client_scope[each.key].id
  name                = "department"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  user_attribute   = "department"
  claim_value_type = "String"
  claim_name       = "department"
}

## lhm-core scope protocol mappers telephoneNumber
resource "keycloak_openid_user_attribute_protocol_mapper" "telephoneNumber" {
  for_each            = toset(local.enabled_realm_ids)
  realm_id            = each.key
  client_scope_id     = keycloak_openid_client_scope.common_client_scope[each.key].id
  name                = "telephoneNumber"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  user_attribute   = "telephoneNumber"
  claim_value_type = "String"
  claim_name       = "telephone_number"
}

# =============================================================================
# lhm-core-saml scope (SAML-Pendant zu lhm-core)
# =============================================================================

resource "keycloak_saml_client_scope" "common_client_scope_saml" {
  for_each = toset(local.enabled_realm_ids)
  # lookup statt each.key: Apply-Reihenfolge fuer Bootstrap-Realms, s.o.
  realm_id    = lookup(var.bootstrap_realm_refs, each.key, each.key)
  name        = "lhm-core-saml"
  description = "LHM standard scope (SAML) – Contains all user attributes typical for City of Munich applications."
}

## lhm-core-saml scope protocol mappers department
resource "keycloak_saml_user_attribute_protocol_mapper" "department_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "department"

  user_attribute             = "department"
  saml_attribute_name        = "department"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers givenname
resource "keycloak_saml_user_property_protocol_mapper" "givenname_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "givenname"

  user_property              = "firstName"
  saml_attribute_name        = "givenname"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers email
resource "keycloak_saml_user_property_protocol_mapper" "email_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "email"

  user_property              = "email"
  saml_attribute_name        = "email"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers surname
resource "keycloak_saml_user_property_protocol_mapper" "surname_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "surname"

  user_property              = "lastName"
  saml_attribute_name        = "surname"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers telephoneNumber
resource "keycloak_saml_user_attribute_protocol_mapper" "telephoneNumber_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "telephoneNumber"

  user_attribute             = "telephoneNumber"
  saml_attribute_name        = "telephoneNumber"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers displayName
resource "keycloak_saml_user_attribute_protocol_mapper" "displayName_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "displayName"

  user_attribute             = "displayName"
  saml_attribute_name        = "displayName"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers username
resource "keycloak_saml_user_property_protocol_mapper" "username_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "username"

  user_property              = "username"
  saml_attribute_name        = "username"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope protocol mappers lhmObjectID
resource "keycloak_saml_user_attribute_protocol_mapper" "lhmObjectID_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "lhmObjectID"

  # Realm-spezifisches user_attribute via protocol_mapper_overrides Variable (analog lhm-core)
  user_attribute             = local.lhmObjectID_attributes[each.key]
  saml_attribute_name        = "lhmObjectID"
  saml_attribute_name_format = "Basic"
}

## lhm-core-saml scope: NameID Mapper (lhmObjectID -> Persistent NameID)
resource "keycloak_generic_protocol_mapper" "lhmObjectID_nameid_saml" {
  for_each        = toset(local.enabled_realm_ids)
  realm_id        = each.key
  client_scope_id = keycloak_saml_client_scope.common_client_scope_saml[each.key].id
  name            = "lhmObjectID to Persistent NameID"
  protocol        = "saml"
  protocol_mapper = "saml-user-attribute-nameid-mapper"

  config = {
    "user.attribute"       = local.lhmObjectID_attributes[each.key]
    "mapper.nameid.format" = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
  }
}

## phone scope protocol mapper phone number
resource "keycloak_openid_user_attribute_protocol_mapper" "phone_number" {
  for_each            = toset(local.realms_for_lookup)
  realm_id            = each.key
  client_scope_id     = data.keycloak_openid_client_scope.phone[each.key].id
  name                = "phone number"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  user_attribute   = "telephoneNumber"
  claim_value_type = "String"
  claim_name       = "phone_number"
}

## phone scope protocol mapper telephoneNumber
resource "keycloak_openid_user_attribute_protocol_mapper" "phone_telephoneNumber" {
  for_each            = toset(local.realms_for_lookup)
  realm_id            = each.key
  client_scope_id     = data.keycloak_openid_client_scope.phone[each.key].id
  name                = "telephoneNumber"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

  user_attribute   = "telephoneNumber"
  claim_value_type = "String"
  claim_name       = "telephone_number"
}

resource "keycloak_realm_default_client_scopes" "default_scopes" {
  for_each = toset(local.enabled_realm_ids)
  realm_id = each.key

  default_scopes = [
    keycloak_openid_client_scope.common_client_scope[each.key].name,
    keycloak_saml_client_scope.common_client_scope_saml[each.key].name,
  ]
}
# Default Scopes - lhm-core (OIDC) und lhm-core-saml (SAML)

# Optional Scopes - Standard Keycloak Scopes + Custom LHM Scopes
# ONLY for existing realms (skip_default_scopes_lookup = false)
# For new realms, this is managed in the root module
resource "keycloak_realm_optional_client_scopes" "optional_scopes" {
  for_each = var.skip_default_scopes_lookup ? [] : toset(local.enabled_realm_ids)
  realm_id = each.key
  optional_scopes = concat(
    # Standard Keycloak Scopes - for existing realms
    [
      "profile",
      "email",
      "phone",
      "acr",
      "web-origins",
      "basic",
      "roles"
    ],
    # Custom LHM Scopes
    var.optional_scopes
  )

  # Die Scope-Namen oben sind nur Strings - ohne explizite Abhaengigkeit darf
  # Terraform diese Zuordnung VOR der Erstellung der referenzierten Scopes
  # anwenden ("client scope 'LHM' not found" beim ersten Apply fuer einen
  # neuen Realm; der zweite Lauf ging dann durch). depends_on erzwingt die
  # richtige Reihenfolge innerhalb eines Applies.
  #
  # default_scopes MUSS zusaetzlich VOR optional_scopes laufen: ein frischer
  # Realm hat profile/email/roles/... als DEFAULT-Scopes; erst wenn
  # default_scopes sie aus der Default-Liste entfernt hat, darf
  # optional_scopes sie als Optional zuweisen - sonst 409 "Duplicate
  # resource error" (real passiert beim ersten ts-predev-Apply 2026-07-13).
  depends_on = [
    keycloak_openid_client_scope.lhm_scope,
    keycloak_openid_client_scope.lhm_extended_scope,
    keycloak_openid_client_scope.roles_scope,
    keycloak_realm_default_client_scopes.default_scopes,
  ]
}
