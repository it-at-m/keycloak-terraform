# ============================================================================
# LHM Demo Setup - VEREINFACHTE VERSION für frische Keycloak-Instanz
# ============================================================================
# Diese Datei erstellt das komplette LHM Demo Setup OHNE Module, damit keine
# Data Sources während der Plan-Phase ausgeführt werden müssen.
# ============================================================================

# 1. LHM Demo Realm erstellen
# ============================================================================
resource "keycloak_realm" "lhm_demo" {
  realm        = "LHM-Demo"
  enabled      = true
  display_name = "LHM Demo Realm"

  # LHM Standard Themes
  # login_theme = "lhm-default.v2"
  # admin_theme = "lhm-admin"

  # Token- & Session-Lebensdauern (IDP Best Practice Empfehlung),
  # siehe Terraform/modules/realm-session-lifetimes/README.md
  sso_session_idle_timeout             = module.realm_session_lifetimes.settings["LHM-Demo"].sso_session_idle_timeout
  sso_session_max_lifespan             = module.realm_session_lifetimes.settings["LHM-Demo"].sso_session_max_lifespan
  revoke_refresh_token                 = module.realm_session_lifetimes.settings["LHM-Demo"].revoke_refresh_token
  refresh_token_max_reuse              = module.realm_session_lifetimes.settings["LHM-Demo"].refresh_token_max_reuse
  access_token_lifespan                = module.realm_session_lifetimes.settings["LHM-Demo"].access_token_lifespan
  offline_session_idle_timeout         = module.realm_session_lifetimes.settings["LHM-Demo"].offline_session_idle_timeout
  offline_session_max_lifespan_enabled = module.realm_session_lifetimes.settings["LHM-Demo"].offline_session_max_lifespan_enabled
  offline_session_max_lifespan         = module.realm_session_lifetimes.settings["LHM-Demo"].offline_session_max_lifespan
  access_code_lifespan_login           = module.realm_session_lifetimes.settings["LHM-Demo"].access_code_lifespan_login
  access_code_lifespan_user_action     = module.realm_session_lifetimes.settings["LHM-Demo"].access_code_lifespan_user_action

  # Internationalization
  internationalization {
    supported_locales = ["de", "en"]
    default_locale    = "de"
  }

  # Security Defenses
  security_defenses {
    headers {
      x_frame_options                     = "SAMEORIGIN"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }
}

# ============================================================================
# Data Sources für Standard Keycloak Client Scopes
# ============================================================================
# Diese Scopes werden automatisch von Keycloak beim Realm-Erstellen angelegt.
# Wir nutzen Data Sources um sie zu referenzieren.
# ============================================================================

data "keycloak_openid_client_scope" "standard_profile" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "profile"

  depends_on = [keycloak_realm.lhm_demo]
}

data "keycloak_openid_client_scope" "standard_email" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "email"

  depends_on = [keycloak_realm.lhm_demo]
}

data "keycloak_openid_client_scope" "standard_acr" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "acr"

  depends_on = [keycloak_realm.lhm_demo]
}

data "keycloak_openid_client_scope" "standard_web_origins" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "web-origins"

  depends_on = [keycloak_realm.lhm_demo]
}

data "keycloak_openid_client_scope" "standard_basic" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "basic"

  depends_on = [keycloak_realm.lhm_demo]
}

# Standard Roles Scope - wird via Data Source referenziert
# Die Konfiguration (include_in_token_scope) wird via deploy-Skript gesetzt
data "keycloak_openid_client_scope" "standard_roles" {
  realm_id = keycloak_realm.lhm_demo.id
  name     = "roles"

  depends_on = [keycloak_realm.lhm_demo]
}


# 1b. User Profile mit Unmanaged Attributes Policy
# ============================================================================
resource "keycloak_realm_user_profile" "lhm_demo_profile" {
  realm_id = keycloak_realm.lhm_demo.id

  # 🎯 WICHTIG: Unmanaged Attributes aktivieren
  unmanaged_attribute_policy = "ENABLED"

  attribute {
    name         = "username"
    display_name = "Username"

    permissions {
      view = ["admin", "user"]
      edit = ["admin"]
    }

    validator {
      name = "length"
      config = {
        min = "3"
        max = "255"
      }
    }

    validator {
      name = "person-name-prohibited-characters"
    }

    validator {
      name = "up-username-not-idn-homograph"
    }
  }

  attribute {
    name         = "email"
    display_name = "Email"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "email"
    }

    validator {
      name = "length"
      config = {
        max = "255"
      }
    }
  }

  attribute {
    name         = "firstName"
    display_name = "First name"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }

  attribute {
    name         = "lastName"
    display_name = "Last name"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }
}

# 2. LHM Standard Scopes mit Modul erstellen
# ============================================================================
module "lhm_demo_scopes" {
  source = "../modules/realm-scopes"

  # Realm Config
  realm_id = [keycloak_realm.lhm_demo.realm]

  # NEW REALM MODE: Skip data source lookups during plan phase
  skip_default_scopes_lookup    = true
  manage_roles_scope            = false # roles scope is auto-created, managed separately
  use_custom_authorities_mapper = false
}

# 2b. Realm Optional Client Scopes - Standard + Custom LHM Scopes
# ============================================================================
# Keycloak erstellt Standard-Scopes automatisch, aber wir müssen sie explizit
# zu den Optional Scopes hinzufügen
resource "keycloak_realm_optional_client_scopes" "lhm_demo_optional" {
  realm_id = keycloak_realm.lhm_demo.id

  optional_scopes = [
    # Standard Keycloak Scopes (per Namen referenzieren)
    data.keycloak_openid_client_scope.standard_profile.name,
    data.keycloak_openid_client_scope.standard_email.name,
    data.keycloak_openid_client_scope.standard_roles.name,
    data.keycloak_openid_client_scope.standard_acr.name,
    data.keycloak_openid_client_scope.standard_web_origins.name,
    data.keycloak_openid_client_scope.standard_basic.name,
    # Custom LHM Scopes
    "LHM",
    "LHM_Extended"
  ]

  depends_on = [
    module.lhm_demo_scopes,
    data.keycloak_openid_client_scope.standard_profile,
    data.keycloak_openid_client_scope.standard_email,
    data.keycloak_openid_client_scope.standard_roles,
    data.keycloak_openid_client_scope.standard_acr,
    data.keycloak_openid_client_scope.standard_web_origins,
    data.keycloak_openid_client_scope.standard_basic
  ]
}

# 3. Clients mit Modulen
# ============================================================================
module "demo_confidential_client" {
  source = "../modules/oidc-client"

  realm_id    = keycloak_realm.lhm_demo.id
  client_id   = "lhm-demo-backend"
  name        = "LHM Demo Backend Application"
  description = "Confidential OIDC Client für Backend-Services"

  client_authenticator_type    = "client-secret"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  service_accounts_enabled     = true
  full_scope_allowed           = false

  root_url            = "https://demo-backend.muenchen.de"
  valid_redirect_uris = ["https://demo-backend.muenchen.de/*", "http://localhost:8080/*"]
  web_origins         = ["https://demo-backend.muenchen.de", "http://localhost:8080"]

  # Keine Scope-Zuweisung - Realm Defaults werden automatisch übernommen
  # default_client_scopes  = ["profile", "email", "lhm-core"]
  # optional_client_scopes = ["roles"]

  roles = {
    "admin" = {
      description     = "Administrator role"
      composite_roles = []
    }
    "tester" = {
      description     = "Tester role"
      composite_roles = []
    }
    "viewer" = {
      description     = "Viewer role"
      composite_roles = []
    }
    "lhm-ab-demo-backend-admin" = {
      description = "⚠️ Internal AD role - grants admin access"
      composite_roles = [
        { role = "admin", client_id = "self" }
      ]
    }
    "lhm-ab-demo-backend-tester" = {
      description = "⚠️ Internal AD role - grants tester access"
      composite_roles = [
        { role = "tester", client_id = "self" }
      ]
    }
    "lhm-ab-demo-backend-viewer" = {
      description = "⚠️ Internal AD role - grants viewer access"
      composite_roles = [
        { role = "viewer", client_id = "self" }
      ]
    }
  }

  depends_on = [
    module.lhm_demo_scopes,
    keycloak_realm_optional_client_scopes.lhm_demo_optional,
    data.keycloak_openid_client_scope.standard_profile,
    data.keycloak_openid_client_scope.standard_email
  ]
}

# 3b. SPA-Client als Template (siehe ADR-003 / docs/architecture/oidc-client-templates.md)
# ============================================================================
# Migration von modules/oidc-client auf oidc-client-spa: Die zugrunde
# liegenden Keycloak-Ressourcen bleiben dank der moved-Bloecke erhalten
# (kein Neuanlegen des Clients/der Rollen).
moved {
  from = module.demo_public_client.keycloak_openid_client.client
  to   = module.demo_public_client.module.oidc_client.keycloak_openid_client.client
}

moved {
  from = module.demo_public_client.keycloak_role.base_roles["admin"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.base_roles["admin"]
}

moved {
  from = module.demo_public_client.keycloak_role.base_roles["tester"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.base_roles["tester"]
}

moved {
  from = module.demo_public_client.keycloak_role.base_roles["viewer"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.base_roles["viewer"]
}

moved {
  from = module.demo_public_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-admin"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-admin"]
}

moved {
  from = module.demo_public_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-tester"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-tester"]
}

moved {
  from = module.demo_public_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-viewer"]
  to   = module.demo_public_client.module.oidc_client.keycloak_role.composite_roles["lhm-ab-demo-frontend-viewer"]
}

module "demo_public_client" {
  source = "../modules/oidc-client-spa"

  realm_id    = keycloak_realm.lhm_demo.id
  client_id   = "lhm-demo-frontend"
  name        = "LHM Demo Frontend Application"
  description = "Public OIDC Client für SPAs (Authorization Code Flow + PKCE)"

  root_url            = "https://demo-frontend.muenchen.de"
  valid_redirect_uris = ["https://demo-frontend.muenchen.de/*", "http://localhost:3000/*", "http://localhost:5173/*"]
  web_origins         = ["https://demo-frontend.muenchen.de", "http://localhost:3000", "http://localhost:5173"]

  roles = {
    "admin" = {
      description     = "Administrator role"
      composite_roles = []
    }
    "tester" = {
      description     = "Tester role"
      composite_roles = []
    }
    "viewer" = {
      description     = "Viewer role"
      composite_roles = []
    }
    "lhm-ab-demo-frontend-admin" = {
      description = "⚠️ Internal AD role - grants admin access"
      composite_roles = [
        { role = "admin", client_id = "self" }
      ]
    }
    "lhm-ab-demo-frontend-tester" = {
      description = "⚠️ Internal AD role - grants tester access"
      composite_roles = [
        { role = "tester", client_id = "self" }
      ]
    }
    "lhm-ab-demo-frontend-viewer" = {
      description = "⚠️ Internal AD role - grants viewer access"
      composite_roles = [
        { role = "viewer", client_id = "self" }
      ]
    }
  }

  depends_on = [
    module.lhm_demo_scopes,
    keycloak_realm_optional_client_scopes.lhm_demo_optional,
    data.keycloak_openid_client_scope.standard_profile,
    data.keycloak_openid_client_scope.standard_email
  ]
}

# 4. Demo Users
# ============================================================================
module "demo_user_admin" {
  source = "../modules/keycloak-user"

  realm_id   = keycloak_realm.lhm_demo.id
  username   = "maria.admin"
  email      = "maria.admin@muenchen.de"
  first_name = "Maria"
  last_name  = "Admin"

  initial_password   = "Demo123!Admin"
  temporary_password = true

  department       = "IT-Referat - IAM"
  telephone_number = "+49 89 233-11111"
  member_of        = ["CN=lhm-ab-demo-backend-admin,OU=Groups,DC=muenchen,DC=de"]

  generate_lhm_object_id = true
  required_actions       = ["UPDATE_PASSWORD", "VERIFY_EMAIL"]

  # WICHTIG: User Profile muss VOR den Users angelegt werden!
  depends_on = [keycloak_realm_user_profile.lhm_demo_profile]
}

module "demo_user_tester" {
  source = "../modules/keycloak-user"

  realm_id   = keycloak_realm.lhm_demo.id
  username   = "thomas.tester"
  email      = "thomas.tester@muenchen.de"
  first_name = "Thomas"
  last_name  = "Tester"

  initial_password   = "Demo123!Test"
  temporary_password = true

  department       = "IT-Referat - QA"
  telephone_number = "+49 89 233-22222"
  member_of        = ["CN=lhm-ab-demo-backend-tester,OU=Groups,DC=muenchen,DC=de"]

  generate_lhm_object_id = true
  required_actions       = ["UPDATE_PASSWORD", "VERIFY_EMAIL"]

  # WICHTIG: User Profile muss VOR den Users angelegt werden!
  depends_on = [keycloak_realm_user_profile.lhm_demo_profile]
}

# Role Assignments
resource "keycloak_user_roles" "admin_backend_roles" {
  realm_id = keycloak_realm.lhm_demo.id
  user_id  = module.demo_user_admin.user_id

  role_ids = [
    module.demo_confidential_client.client_roles["lhm-ab-demo-backend-admin"]
  ]
}

resource "keycloak_user_roles" "tester_backend_roles" {
  realm_id = keycloak_realm.lhm_demo.id
  user_id  = module.demo_user_tester.user_id

  role_ids = [
    module.demo_confidential_client.client_roles["lhm-ab-demo-backend-tester"]
  ]
}

# Outputs
output "lhm_demo_realm_info" {
  value = {
    realm_name   = keycloak_realm.lhm_demo.realm
    realm_id     = keycloak_realm.lhm_demo.id
    display_name = keycloak_realm.lhm_demo.display_name
    login_theme  = keycloak_realm.lhm_demo.login_theme
  }
}

output "lhm_demo_clients" {
  sensitive = true
  value = {
    backend = {
      client_id     = module.demo_confidential_client.client_id
      client_secret = module.demo_confidential_client.client_secret
    }
    frontend = {
      client_id = module.demo_public_client.client_id
    }
  }
}

output "lhm_demo_users" {
  sensitive = true
  value = {
    admin  = { username = "maria.admin", password = "Demo123!Admin" }
    tester = { username = "thomas.tester", password = "Demo123!Test" }
  }
}
