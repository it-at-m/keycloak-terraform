variable "realm_keys" {
  description = "Map of RSA keys to manage per realm"
  type = map(object({
    realm_id           = string
    name               = string
    priority           = number
    certificate        = string
    private_key        = string
    algorithm          = optional(string, "RS256")
    enabled            = optional(bool, true)
    parent_id          = optional(string, null)  # Optional: Explizite UUID für Component parentId (Workaround für public Realm)
    key_provider_id    = optional(string, "rsa") # Key type: "rsa" für Signatur (sig), "rsa-enc" für Verschlüsselung (enc)
    provider_id        = optional(string, null)  # Optional: Existing provider ID for import
    use_api_workaround = optional(string, "")    # Optional: Parent ID für API-Erstellung (z.B. "Public" oder "test"), leer = kein Workaround
  }))
  default = {}
  
  validation {
    condition     = alltrue([for k, v in var.realm_keys : v.priority >= 0 && v.priority <= 1000])
    error_message = "Priority must be between 0 and 1000."
  }
}

# Optional: Secrets aus externen Sources
variable "certificate_secrets" {
  description = "Map of certificate secrets (avoid storing in Terraform state)"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "private_key_secrets" {
  description = "Map of private key secrets (avoid storing in Terraform state)"
  type        = map(string)
  sensitive   = true
  default     = {}
}
