# Token- & Session-Lebensdauern (IDP Best Practice Empfehlung) für alle
# Realms in local. Siehe Terraform/modules/realm-session-lifetimes/README.md.
#
# WICHTIG: realm_id hier bewusst als literaler String (nicht
# keycloak_realm.X.realm) - sonst entsteht ein Terraform-Zyklus, da die
# keycloak_realm-Ressource ihrerseits die Outputs dieses Moduls referenziert.
module "realm_session_lifetimes" {
  source = "../modules/realm-session-lifetimes"

  realm_id = [
    "LHM-Demo",
  ]
}
