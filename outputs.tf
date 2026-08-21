output "storage_account_name" {
  value       = local.storage_account_name
  description = "Name of the Azure storage account used as the export destination."
}

output "storage_account_id" {
  value       = local.storage_account_id
  description = "Resource ID of the Azure storage account used as the export destination."
}

output "storage_account_primary_blob_endpoint" {
  value       = local.storage_account_primary_blob_endpoint
  description = "Primary blob endpoint of the export storage account (created or reused)."
}

output "blob_services_resource_id" {
  value       = local.blob_services_resource_id
  description = <<-EOT
    ARM id of the account blob service (`…/blobServices/default`). Use as
    `target_resource_id` on `azurerm_monitor_diagnostic_setting` if you configure logging
    outside this module.
  EOT
}

output "blob_diagnostic_setting_id" {
  value       = try(azurerm_monitor_diagnostic_setting.blob[0].id, null)
  description = "Id of the blob diagnostic setting created when `blob_diagnostics` is set; otherwise null."
}

output "account_replication_type" {
  value       = local.create_storage_account ? azurerm_storage_account.worklytics[0].account_replication_type : null
  description = "Replication of a storage account created by this module; null when reusing an existing account."
}

output "infrastructure_encryption_enabled" {
  value       = local.create_storage_account ? azurerm_storage_account.worklytics[0].infrastructure_encryption_enabled : null
  description = "Whether infrastructure encryption is on for a created account; null when reusing an existing account."
}

output "storage_container_name" {
  value       = local.storage_container_name
  description = "Name of the blob container Worklytics will write exports to."
}

output "storage_container_resource_manager_id" {
  value       = local.storage_container_resource_manager_id
  description = "ARM resource ID of the export blob container. Useful for additional role assignments."
}

output "application_client_id" {
  value       = azuread_application.worklytics.client_id
  description = "Entra application (client) ID Worklytics uses when exchanging a Google ID token."
}

output "service_principal_object_id" {
  value       = azuread_service_principal.worklytics.object_id
  description = "Object ID of the Entra service principal granted blob access. Useful for composing extra RBAC."
}

output "todo_markdown" {
  value       = var.todos_as_outputs ? local.todo_content : null
  description = "Actions that must be performed outside of Terraform (markdown format)."
}
