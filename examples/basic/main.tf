# Development / CI example only. Customers should copy from the root README or
# examples/basic-remote/ (Terraform Registry source), not this relative path.

module "worklytics_export" {
  # Relative source so CI tests *this* checkout. Published usage:
  #   source  = "Worklytics/worklytics-export/azurerm"
  #   version = "~> 0.2.0"
  source = "../../"

  resource_name_prefix   = var.resource_name_prefix
  worklytics_tenant_id   = var.worklytics_tenant_id
  azure_tenant_id        = var.azure_tenant_id
  resource_group_name    = var.resource_group_name
  location               = var.location
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  owners                 = var.owners
}

resource "local_file" "todo" {
  count = var.write_todo_local_file ? 1 : 0

  filename = "TODO - configure export in worklytics.md"
  content  = module.worklytics_export.todo_markdown
}

output "storage_account_name" {
  value = module.worklytics_export.storage_account_name
}

output "storage_container_name" {
  value = module.worklytics_export.storage_container_name
}

output "application_client_id" {
  value = module.worklytics_export.application_client_id
}

output "service_principal_object_id" {
  value = module.worklytics_export.service_principal_object_id
}

output "todo_markdown" {
  value = module.worklytics_export.todo_markdown
}
