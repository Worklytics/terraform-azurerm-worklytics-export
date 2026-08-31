# Functional unit tests. Mocked Azure providers; no cloud credentials required.
# Requires Terraform >= 1.7 (`mock_provider`).

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "rg-worklytics-export-test"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-worklytics-export-test"
    }
  }

  mock_data "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-worklytics-export-test/providers/Microsoft.Storage/storageAccounts/existingacct0001"
      name                  = "existingacct0001"
      primary_blob_endpoint = "https://existingacct0001.blob.core.windows.net/"
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-worklytics-export-test/providers/Microsoft.Storage/storageAccounts/createdacct0001"
      name                              = "createdacct0001"
      primary_blob_endpoint             = "https://createdacct0001.blob.core.windows.net/"
      account_replication_type          = "LRS"
      infrastructure_encryption_enabled = true
      shared_access_key_enabled         = false
    }
  }

  mock_resource "azurerm_storage_container" {
    defaults = {
      name = "worklytics-export-container"
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-worklytics-export-test/providers/Microsoft.Storage/storageAccounts/createdacct0001/blobServices/default/containers/worklytics-export-container"
    }
  }

  mock_resource "azurerm_role_assignment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000099"
    }
  }

  mock_resource "azurerm_monitor_diagnostic_setting" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-worklytics-export-test/providers/Microsoft.Insights/diagnosticSettings/blob"
    }
  }
}

mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/00000000-0000-0000-0000-000000000001"
      client_id = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "azuread_service_principal" {
    defaults = {
      # azuread v3: .id is the Graph path; .object_id is the GUID Azure RBAC needs.
      id        = "/servicePrincipals/00000000-0000-0000-0000-000000000002"
      object_id = "00000000-0000-0000-0000-000000000002"
      client_id = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "azuread_application_federated_identity_credential" {
    defaults = {
      id            = "/applications/00000000-0000-0000-0000-000000000001/federatedIdentityCredentials/fic"
      credential_id = "fic"
    }
  }
}

variables {
  worklytics_tenant_id = "123456789012345678901"
  azure_tenant_id      = "11111111-1111-1111-1111-111111111111"
  resource_group_name  = "rg-worklytics-export-test"
  todos_as_local_files = false
}

run "creates_storage_when_omitted" {
  command = plan

  assert {
    condition     = length(azurerm_storage_account.worklytics) == 1
    error_message = "Expected a storage account to be created when storage_account_name is omitted."
  }

  assert {
    condition     = length(azurerm_storage_container.worklytics) == 1
    error_message = "Expected a container to be created when storage_container_name is omitted."
  }

  assert {
    condition     = azurerm_role_assignment.role_contributor.role_definition_name == "Storage Blob Data Contributor"
    error_message = "Worklytics must be granted Storage Blob Data Contributor on the container."
  }

  assert {
    condition     = azurerm_role_assignment.role_delegator.role_definition_name == "Storage Blob Delegator"
    error_message = "Worklytics must be granted Storage Blob Delegator on the storage account."
  }

  assert {
    condition     = length(azuread_application_federated_identity_credential.worklytics) == 1
    error_message = "Federated credential must be created when worklytics_tenant_id is set."
  }

  assert {
    condition     = azuread_application_federated_identity_credential.worklytics[0].subject == var.worklytics_tenant_id
    error_message = "Federated credential subject must be the Worklytics tenant numeric ID."
  }

  assert {
    condition     = azuread_application_federated_identity_credential.worklytics[0].issuer == "https://accounts.google.com"
    error_message = "Federated credential issuer must be Google accounts."
  }

  assert {
    condition     = azurerm_storage_account.worklytics[0].account_replication_type == "LRS"
    error_message = "Created accounts should default to LRS; pass account_replication_type for geo-redundancy."
  }

  assert {
    condition     = azurerm_storage_account.worklytics[0].infrastructure_encryption_enabled == true
    error_message = "Created storage accounts should enable infrastructure encryption by default."
  }

  assert {
    condition     = azurerm_storage_account.worklytics[0].shared_access_key_enabled == false
    error_message = "Created storage accounts should disable shared access keys (Entra/WIF only)."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.blob) == 0
    error_message = "Blob diagnostics must be skipped unless blob_diagnostics is set."
  }
}

run "reuses_existing_storage_account" {
  command = plan

  variables {
    storage_account_name = "existingacct0001"
  }

  assert {
    condition     = length(azurerm_storage_account.worklytics) == 0
    error_message = "Should not create a storage account when storage_account_name is provided."
  }

  assert {
    condition     = length(azurerm_storage_container.worklytics) == 1
    error_message = "Should still create a container when only the account is reused."
  }
}

run "reuses_existing_account_and_container" {
  command = plan

  variables {
    storage_account_name   = "existingacct0001"
    storage_container_name = "already-there"
  }

  assert {
    condition     = length(azurerm_storage_account.worklytics) == 0
    error_message = "Should not create a storage account when one is provided."
  }

  assert {
    condition     = length(azurerm_storage_container.worklytics) == 0
    error_message = "Should not create a container when both account and container names are provided."
  }

  assert {
    condition     = output.storage_container_name == "already-there"
    error_message = "Output container name should match the provided existing container."
  }
}

run "skips_federated_credential_when_tenant_id_null" {
  command = plan

  variables {
    worklytics_tenant_id = null
  }

  assert {
    condition     = length(azuread_application_federated_identity_credential.worklytics) == 0
    error_message = "Pre-production (null tenant id) should not trust an external identity."
  }

  assert {
    condition     = azuread_application.worklytics.display_name == "${var.resource_name_prefix}app"
    error_message = "Entra application should still be created for pre-production review."
  }
}

run "rejects_non_numeric_tenant_id" {
  command = plan

  variables {
    worklytics_tenant_id = "not-a-numeric-id"
  }

  expect_failures = [
    var.worklytics_tenant_id,
  ]
}

run "rejects_short_tenant_id" {
  command = plan

  variables {
    worklytics_tenant_id = "1234567890"
  }

  expect_failures = [
    var.worklytics_tenant_id,
  ]
}

run "rejects_invalid_storage_account_name" {
  command = plan

  variables {
    storage_account_name = "NOT-VALID"
  }

  expect_failures = [
    var.storage_account_name,
  ]
}

run "rejects_invalid_storage_container_name" {
  command = plan

  variables {
    storage_container_name = "NOT_VALID"
  }

  expect_failures = [
    var.storage_container_name,
  ]
}

run "rejects_invalid_replication_type" {
  command = plan

  variables {
    account_replication_type = "LOCAL"
  }

  expect_failures = [
    var.account_replication_type,
  ]
}

run "rejects_blob_diagnostics_without_destination" {
  command = plan

  variables {
    blob_diagnostics = {}
  }

  expect_failures = [
    var.blob_diagnostics,
  ]
}

run "creates_blob_diagnostics_when_destination_set" {
  command = plan

  variables {
    blob_diagnostics = {
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/logs"
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.blob) == 1
    error_message = "Blob diagnostic setting should be created when a destination is provided."
  }
}

run "uses_grs_when_requested" {
  command = plan

  variables {
    account_replication_type = "GRS"
  }

  assert {
    condition     = azurerm_storage_account.worklytics[0].account_replication_type == "GRS"
    error_message = "Created account should use the requested replication type."
  }
}

run "todo_uses_production_worklytics_host" {
  command = apply

  variables {
    todos_as_outputs       = true
    storage_account_name   = "existingacct0001"
    storage_container_name = "already-there"
  }

  assert {
    condition     = strcontains(output.todo_markdown, "https://app.worklytics.co/analytics/data-export/connect?")
    error_message = "TODO should deep-link to production app.worklytics.co /analytics/data-export/connect."
  }

  assert {
    condition     = !strcontains(output.todo_markdown, "worklytics-dev")
    error_message = "TODO must not deep-link to a worklytics-dev host."
  }

  assert {
    condition     = strcontains(output.connect_url, "https://app.worklytics.co/analytics/data-export/connect?")
    error_message = "connect_url should use the production host by default."
  }
}

run "todo_uses_custom_worklytics_host" {
  command = apply

  variables {
    todos_as_outputs       = true
    worklytics_host        = "analytics.example.com"
    storage_account_name   = "existingacct0001"
    storage_container_name = "already-there"
  }

  assert {
    condition     = strcontains(output.todo_markdown, "https://analytics.example.com/analytics/data-export/connect?")
    error_message = "TODO should use worklytics_host when overridden (custom domain)."
  }

  assert {
    condition     = !strcontains(output.todo_markdown, "https://app.worklytics.co/")
    error_message = "Custom worklytics_host should replace the production default in TODOs."
  }
}

run "rejects_worklytics_host_url" {
  command = plan

  variables {
    worklytics_host = "https://app.worklytics.co"
  }

  expect_failures = [
    var.worklytics_host,
  ]
}
