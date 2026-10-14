terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7.0"
    }
  }
}

resource "keycloak_saml_client" "client" {
  realm_id  = var.realm_id
  client_id = var.client_id
  name      = var.name
  enabled   = var.enabled

  description = var.description

  # SAML Processing
  include_authn_statement   = var.include_authn_statement
  sign_documents            = var.sign_documents
  sign_assertions           = var.sign_assertions
  encrypt_assertions        = var.encrypt_assertions
  client_signature_required = var.client_signature_required

  signature_algorithm     = var.signature_algorithm
  signature_key_name      = var.signature_key_name
  canonicalization_method = var.canonicalization_method

  name_id_format       = var.name_id_format
  force_name_id_format = var.force_name_id_format

  force_post_binding   = var.force_post_binding
  front_channel_logout = var.front_channel_logout

  # URLs
  root_url            = var.root_url
  base_url            = var.base_url
  valid_redirect_uris = var.valid_redirect_uris

  master_saml_processing_url          = var.master_saml_processing_url
  assertion_consumer_post_url         = var.assertion_consumer_post_url
  assertion_consumer_redirect_url     = var.assertion_consumer_redirect_url
  logout_service_post_binding_url     = var.logout_service_post_binding_url
  logout_service_redirect_binding_url = var.logout_service_redirect_binding_url

  idp_initiated_sso_url_name    = var.idp_initiated_sso_url_name
  idp_initiated_sso_relay_state = var.idp_initiated_sso_relay_state

  # Zertifikate (Service Provider)
  signing_certificate    = var.signing_certificate
  encryption_certificate = var.encryption_certificate

  encryption_algorithm                = var.encryption_algorithm
  encryption_key_algorithm            = var.encryption_key_algorithm
  encryption_digest_method            = var.encryption_digest_method
  encryption_mask_generation_function = var.encryption_mask_generation_function

  # Consent & Scope
  full_scope_allowed = var.full_scope_allowed
  consent_required   = var.consent_required

  # AD-Bindung: dediziertes Client-Attribut fuer die AD-Provisionierung
  # (OU/Gruppen-Ableitung), entkoppelt vom Anzeigenamen. Als letztes
  # merge-Argument -> gewinnt gegen einen evtl. gleichnamigen Key in
  # var.extra_attributes.
  extra_config = merge(
    var.extra_attributes,
    var.ad_app_identifier != null ? {
      "lhm.ad.app.identifier" = var.ad_app_identifier
    } : {},
    length(var.contact_emails) > 0 ? {
      "lhm.app.contact.emails" = join(",", var.contact_emails)
    } : {}
  )
}

# =============================================================================
# Attribute Mapping
# =============================================================================

resource "keycloak_saml_user_attribute_protocol_mapper" "attribute_mappers" {
  for_each = var.saml_attribute_mappers

  realm_id  = var.realm_id
  client_id = keycloak_saml_client.client.id
  name      = each.key

  user_attribute             = each.value.user_attribute
  saml_attribute_name        = each.value.saml_attribute_name
  saml_attribute_name_format = each.value.saml_attribute_name_format
  friendly_name              = each.value.friendly_name
  aggregate_attributes       = each.value.aggregate_attributes
}

# =============================================================================
# Client Roles (inkl. Composite-Rollen) - analog modules/oidc-client
# =============================================================================

locals {
  composite_mappings = flatten([
    for role_name, role_def in var.roles : [
      for composite in try(role_def.composite_roles, []) : {
        parent_role = role_name
        child_role  = composite.role
        client_id   = try(composite.client_id, null) // null = Realm-Role, "self" = gleicher Client, sonst Client-UUID
      }
    ]
  ])
}

# Realm roles (client_id = null)
data "keycloak_role" "realm_composite_roles" {
  for_each = {
    for m in local.composite_mappings :
    "${m.parent_role}:${m.child_role}" => m
    if m.client_id == null
  }
  realm_id = var.realm_id
  name     = each.value.child_role
}

# Foreign client roles (client_id != null && != "self") - expects client UUID
data "keycloak_role" "client_composite_roles" {
  for_each = {
    for m in local.composite_mappings :
    "${m.parent_role}:${m.child_role}:${m.client_id}" => m
    if m.client_id != null && m.client_id != "self"
  }
  realm_id  = var.realm_id
  client_id = each.value.client_id
  name      = each.value.child_role
}

# 1. Create basic roles (without composites)
resource "keycloak_role" "base_roles" {
  for_each = {
    for role_name, role_def in var.roles :
    role_name => role_def
    if length(try(role_def.composite_roles, [])) == 0
  }

  realm_id    = var.realm_id
  client_id   = keycloak_saml_client.client.id
  name        = each.key
  description = try(each.value.description, "")
}

# 2. Composite roles separately (can refer to base_roles)
resource "keycloak_role" "composite_roles" {
  for_each = {
    for role_name, role_def in var.roles :
    role_name => role_def
    if length(try(role_def.composite_roles, [])) > 0
  }

  realm_id    = var.realm_id
  client_id   = keycloak_saml_client.client.id
  name        = each.key
  description = try(each.value.description, "")

  composite_roles = concat(
    # Realm roles
    [
      for m in local.composite_mappings :
      data.keycloak_role.realm_composite_roles["${m.parent_role}:${m.child_role}"].id
      if m.parent_role == each.key && m.client_id == null
    ],
    # Basis roles same Clients (client_id = "self")
    [
      for m in local.composite_mappings :
      keycloak_role.base_roles[m.child_role].id
      if m.parent_role == each.key && m.client_id == "self"
    ],
    # Foreign client roles
    [
      for m in local.composite_mappings :
      data.keycloak_role.client_composite_roles["${m.parent_role}:${m.child_role}:${m.client_id}"].id
      if m.parent_role == each.key && m.client_id != null && m.client_id != "self"
    ]
  )

  depends_on = [keycloak_role.base_roles]
}

# 3. Output for all roles (merge of both resources)
locals {
  all_roles = merge(
    { for k, v in keycloak_role.base_roles : k => v.id },
    { for k, v in keycloak_role.composite_roles : k => v.id }
  )
}
