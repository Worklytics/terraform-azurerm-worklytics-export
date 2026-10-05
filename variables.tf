# Platform-specific settings omit cloud prefixes — this module implies Azure.

variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable. When `storage_container_name` is unset, also used to generate a blob container name via `{prefix-with-hyphens}container`."
  default     = "worklytics-export-"
}

variable "worklytics_tenant_id" {
  type        = string
  description = "Numeric ID of your Worklytics tenant's service account (obtain from Worklytics App)."

  default  = null
  nullable = true

  validation {
    condition     = var.worklytics_tenant_id == null || can(regex("^\\d{21}$", var.worklytics_tenant_id))
    error_message = "`worklytics_tenant_id` must be a 21-digit numeric value (or `null`, for pre-production use case where you don't want external entity to be allowed to federate into it)."
  }
}

variable "azure_tenant_id" {
  type        = string
  description = "Entra (Azure AD) tenant ID. Used for Worklytics connection instructions and deep-links."
}

variable "resource_group_name" {
  type        = string
  description = <<-EOT
    Resource group for a storage account created by this module, and for looking up an existing
    account when `storage_account_name` is set. Must already exist.
  EOT
}

variable "location" {
  type        = string
  description = <<-EOT
    Region for a storage account created by this module. If null, the resource group's location
    is used. Ignored when no account is created.
  EOT
  default = null
}

variable "storage_account_name" {
  type        = string
  description = <<-EOT
    Existing storage account for the export destination. If null, a storage account is created
    in `resource_group_name`.
  EOT
  default  = null
  nullable = true

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "`storage_account_name` must be 3-24 lowercase letters and numbers."
  }
}

variable "storage_container_name" {
  type        = string
  description = <<-EOT
    Exact blob container name for the export destination. When set, used instead of a name
    derived from `resource_name_prefix`. Set when reusing an existing container (together with
    `storage_account_name`) or when you need a specific name on a new storage account. If null,
    a private container is created with the default `{prefix}container` name. Providing both
    `storage_account_name` and `storage_container_name` skips container creation; the module
    only grants Worklytics access.
  EOT
  default  = null
  nullable = true

  validation {
    condition = var.storage_container_name == null || can(regex(
      "^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])$",
      var.storage_container_name
    ))
    error_message = "`storage_container_name` must be 3-63 chars of lowercase letters, numbers, and hyphens."
  }
}

variable "account_replication_type" {
  type        = string
  description = <<-EOT
    Replication for a storage account *created* by this module. Ignored when reusing an existing
    account. `LRS` is the default (cost); production durability should use `GRS`, `RAGRS`,
    `GZRS`, or `RAGZRS`. Switching between LRS/GRS/RAGRS and ZRS/GZRS/RAGZRS forces a new account.
  EOT
  default = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "`account_replication_type` must be one of LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "infrastructure_encryption_enabled" {
  type        = bool
  description = <<-EOT
    Double-encrypt a storage account *created* by this module (service + infrastructure keys).
    Can only be set at creation; ignored when reusing an existing account. Default is `true`.
  EOT
  default = true
}

variable "blob_diagnostics" {
  type = object({
    log_analytics_workspace_id     = optional(string)
    storage_account_id             = optional(string)
    eventhub_authorization_rule_id = optional(string)
    eventhub_name                  = optional(string)
  })
  description = <<-EOT
    Monitor destination for blob StorageRead/Write/Delete logs. Null (default) skips logging —
    pass a workspace, a *different* storage account, or an Event Hub you already own. Do not send
    logs to the export account itself. When omitted, compose `azurerm_monitor_diagnostic_setting`
    yourself using `blob_services_resource_id`.
  EOT
  default  = null
  nullable = true

  validation {
    condition = var.blob_diagnostics == null || (
      length(compact([
        try(var.blob_diagnostics.log_analytics_workspace_id, null),
        try(var.blob_diagnostics.storage_account_id, null),
        try(var.blob_diagnostics.eventhub_authorization_rule_id, null),
      ])) == 1
    )
    error_message = "`blob_diagnostics` must set exactly one of log_analytics_workspace_id, storage_account_id, or eventhub_authorization_rule_id."
  }
}

variable "owners" {
  type        = set(string)
  description = "Object IDs set as owners of the Entra application created for Worklytics."
  default     = []
}

# TODO: remove in next major — sensible default covers typical Worklytics federation.
variable "federated_identity_description" {
  type        = string
  description = "Optional description of the federated identity credential."
  default     = "Allows the Worklytics tenant GCP service account to write data exports to Azure Blob Storage."
}

# TODO: remove in next major — sensible default covers typical Worklytics federation.
variable "federated_identity_issuer" {
  type        = string
  description = <<-EOT
    URL of the external identity provider; must match the issuer claim of the token being
    exchanged. The combination of issuer and subject must be unique on the app.
  EOT
  default = "https://accounts.google.com"
}

variable "worklytics_host" {
  type        = string
  description = "host of worklytics instance where tenant resides. (e.g. app.worklytics.co for prod; but may differ for dev/staging)"
  default     = "app.worklytics.co"

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$", var.worklytics_host))
    error_message = "`worklytics_host` must be a hostname (e.g. app.worklytics.co), not a URL."
  }
}

