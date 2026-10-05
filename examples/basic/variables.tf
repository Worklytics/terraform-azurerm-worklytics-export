variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription in which to provision. Required by azurerm 4.x provider configuration."
  default     = null
}

variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-export-"
}

variable "worklytics_tenant_id" {
  type        = string
  description = "Numeric ID of your Worklytics tenant's service account (obtain from Worklytics App)."
  default     = null
}

variable "azure_tenant_id" {
  type        = string
  description = "The Azure tenant ID where the application will be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where the storage account is located or will be created."
}

variable "location" {
  type        = string
  description = "Azure region for a storage account created by this module. If null, uses the resource group location."
  default     = null
}

variable "storage_account_name" {
  type        = string
  description = "Existing storage account to reuse. If null, the module creates one."
  default     = null
}

variable "storage_container_name" {
  type        = string
  description = "Exact container name to create or reuse. If null, the module uses `{resource_name_prefix}container`."
  default     = null
}

variable "owners" {
  type        = set(string)
  description = "Object IDs set as owners of the Entra application."
  default     = []
}

variable "write_todo_local_file" {
  type        = bool
  description = "Whether to write module todo_markdown to a local markdown file in this example."
  default     = true
}
