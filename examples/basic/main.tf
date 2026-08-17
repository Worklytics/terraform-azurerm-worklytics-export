# Development / CI example only. Customers should copy from the root README or
# examples/basic-remote/ (Terraform Registry source), not this relative path.

module "worklytics_export" {
  # Relative source so CI tests *this* checkout. Published usage:
  #   source  = "Worklytics/worklytics-export/azurerm"
  #   version = "~> 0.1.0"
  source = "../../"

  resource_name_prefix       = var.resource_name_prefix
  worklytics_tenant_id       = var.worklytics_tenant_id
  worklytics_tenant_sa_email = var.worklytics_tenant_sa_email
  azure_tenant_id            = var.azure_tenant_id
  resource_group_name        = var.resource_group_name
  location                   = var.location
  storage_account_name       = var.storage_account_name
  storage_container_name     = var.storage_container_name
  owners                     = var.owners
  todos_as_local_files       = var.todos_as_local_files
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
