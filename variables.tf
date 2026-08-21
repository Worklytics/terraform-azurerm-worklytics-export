variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-export-"
}

variable "worklytics_tenant_id" {
  type        = string
  description = <<-EOT
    Numeric unique ID of your Worklytics tenant's GCP service account (obtain from the Worklytics
    app). This is a 21-digit value used as the subject of the Entra federated identity credential.
    It is the same identifier used by the AWS export and Azure import modules; it is *not* the SA
    email. Set to `null` only for pre-production review, where the Entra app is created but no
    external identity is trusted to federate into it.
  EOT
  default     = null
  nullable    = true

  validation {
    condition     = var.worklytics_tenant_id == null || can(regex("^\\d{21}$", var.worklytics_tenant_id))
    error_message = "`worklytics_tenant_id` must be a 21-digit numeric value (or `null` for pre-production)."
  }
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = <<-EOT
    Optional email of your Worklytics tenant's GCP service account. Used only in generated
    instructions; federation is keyed by `worklytics_tenant_id`.
  EOT
  default     = null
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
    Azure region for a storage account created by this module. If null, the resource group's
    location is used. Ignored when no account is created.
  EOT
  default     = null
}

variable "storage_account_name" {
  type        = string
  description = <<-EOT
    Existing Azure storage account for the export destination. If null, a storage account is
    created in `resource_group_name`.
  EOT
  default     = null
  nullable    = true

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "`storage_account_name` must be 3-24 lowercase letters and numbers."
  }
}

variable "storage_container_name" {
  type        = string
  description = <<-EOT
    Existing blob container for the export destination. If null, a private container is created.
    Providing both `storage_account_name` and `storage_container_name` skips storage creation;
    the module only grants Worklytics access.
  EOT
  default     = null
  nullable    = true

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
  default     = "LRS"

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
  default     = true
}

variable "blob_diagnostics" {
  type = object({
    log_analytics_workspace_id     = optional(string)
    storage_account_id             = optional(string)
    eventhub_authorization_rule_id = optional(string)
    eventhub_name                  = optional(string)
  })
  description = <<-EOT
    Azure Monitor destination for blob StorageRead/Write/Delete logs. Null (default) skips
    logging — pass a workspace, a *different* storage account, or an Event Hub you already
    own. Do not send logs to the export account itself. When omitted, compose
    `azurerm_monitor_diagnostic_setting` yourself using `blob_services_resource_id`.
  EOT
  default     = null
  nullable    = true

  validation {
    # try() so Terraform < 1.10 can validate when the default null object is used;
    # those versions still evaluate both sides of || and error on null.attr.
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

variable "federated_identity_description" {
  type        = string
  description = "Optional description of the federated identity credential."
  default     = "Allows the Worklytics tenant GCP service account to write data exports to Azure Blob Storage."
}

variable "federated_identity_issuer" {
  type        = string
  description = <<-EOT
    URL of the external identity provider; must match the issuer claim of the token being
    exchanged. The combination of issuer and subject must be unique on the app.
  EOT
  default     = "https://accounts.google.com"
}

variable "worklytics_host" {
  type        = string
  description = <<-EOT
    Hostname of the Worklytics app used in generated connect TODOs and deep-links. Defaults to
    production (`app.worklytics.co`). Override only for a custom domain (or a non-prod instance).
    Pass the host only — no scheme or path (the module prefixes `https://`).
  EOT
  default     = "app.worklytics.co"

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$", var.worklytics_host))
    error_message = "`worklytics_host` must be a hostname (e.g. app.worklytics.co), not a URL."
  }
}

variable "todos_as_outputs" {
  type        = bool
  description = <<-EOT
    Whether to render TODOs as outputs (useful if you're using Terraform Cloud/Enterprise, or
    somewhere else where the filesystem is not readily accessible to you).
  EOT
  default     = false
}

variable "todos_as_local_files" {
  type        = bool
  description = "Whether to render TODOs as flat files."
  default     = true
}
