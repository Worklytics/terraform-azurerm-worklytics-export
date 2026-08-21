data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  # This is the recommended value from MSFT, as it is what Entra expects in the "aud" claim of
  # the token. See docs:
  # https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#important-considerations-and-restrictions
  federated_identity_audience = "api://AzureADTokenExchange"

  container_name_prefix = replace(var.resource_name_prefix, "_", "-")

  create_storage_account = var.storage_account_name == null
  # A brand-new account cannot host an "existing" container; always create one in that case.
  create_container = var.storage_account_name == null || var.storage_container_name == null

  generated_container_name = coalesce(
    var.storage_container_name,
    "${local.container_name_prefix}container"
  )
}

resource "random_id" "storage_account" {
  count = local.create_storage_account ? 1 : 0

  # 8 bytes → 16 hex chars; with the `w8se` prefix this is a 20-char globally unique name
  # (Azure storage account names are 3-24 lowercase alphanumeric).
  byte_length = 8
}

data "azurerm_storage_account" "existing" {
  count = local.create_storage_account ? 0 : 1

  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

# trivy:ignore:AVD-AZU-0012 Public network access is required so Worklytics (GCP) can write objects.
# trivy:ignore:AVD-AZU-0057 Blob logging is Azure Monitor diagnostics (var.blob_diagnostics); Trivy only looks for legacy queue analytics.
# trivy:ignore:AVD-AZU-0058 LRS is the cost-conscious default; pass account_replication_type = "GRS" (or GZRS) for geo-redundancy.
# trivy:ignore:AVD-AZU-0061 On by default via infrastructure_encryption_enabled; Trivy may not resolve the variable.
resource "azurerm_storage_account" "worklytics" {
  count = local.create_storage_account ? 1 : 0

  # Globally unique, valid storage account name. Prefix is not used here because it may
  # contain hyphens and would be truncated if mixed with a uniqueness suffix.
  name                              = "w8se${random_id.storage_account[0].hex}"
  resource_group_name               = var.resource_group_name
  location                          = coalesce(var.location, data.azurerm_resource_group.this.location)
  account_tier                      = "Standard"
  account_replication_type          = var.account_replication_type
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    purpose = "worklytics-export"
  }

  lifecycle {
    ignore_changes = [
      # don't conflict with tags customers might wish to add themselves
      tags,
    ]
  }
}

locals {
  storage_account_name = local.create_storage_account ? azurerm_storage_account.worklytics[0].name : var.storage_account_name
  storage_account_id   = local.create_storage_account ? azurerm_storage_account.worklytics[0].id : data.azurerm_storage_account.existing[0].id
  storage_account_primary_blob_endpoint = (
    local.create_storage_account
    ? azurerm_storage_account.worklytics[0].primary_blob_endpoint
    : data.azurerm_storage_account.existing[0].primary_blob_endpoint
  )
  blob_services_resource_id = "${local.storage_account_id}/blobServices/default"
}

# Azure Monitor logs for the blob service (the export path). Requires a customer-owned
# destination; skipped when blob_diagnostics is null.
resource "azurerm_monitor_diagnostic_setting" "blob" {
  count = var.blob_diagnostics == null ? 0 : 1

  name               = "${trimsuffix(var.resource_name_prefix, "-")}-blob-diagnostics"
  target_resource_id = local.blob_services_resource_id

  log_analytics_workspace_id     = try(var.blob_diagnostics.log_analytics_workspace_id, null)
  log_analytics_destination_type = try(var.blob_diagnostics.log_analytics_workspace_id, null) == null ? null : "Dedicated"
  storage_account_id             = try(var.blob_diagnostics.storage_account_id, null)
  eventhub_authorization_rule_id = try(var.blob_diagnostics.eventhub_authorization_rule_id, null)
  eventhub_name                  = try(var.blob_diagnostics.eventhub_name, null)

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }
}

resource "azurerm_storage_container" "worklytics" {
  count = local.create_container ? 1 : 0

  name                  = local.generated_container_name
  storage_account_id    = local.storage_account_id
  container_access_type = "private"
}

locals {
  storage_container_name = local.generated_container_name
  storage_container_resource_manager_id = (
    local.create_container
    ? azurerm_storage_container.worklytics[0].id
    : "${local.storage_account_id}/blobServices/default/containers/${local.generated_container_name}"
  )
}

# Entra application: storage container access via federated identity (GCP → Azure)
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application
resource "azuread_application" "worklytics" {
  display_name = "${var.resource_name_prefix}app"

  feature_tags {
    hide       = true
    enterprise = false
    gallery    = false
  }

  owners = var.owners
}

resource "azuread_service_principal" "worklytics" {
  client_id = azuread_application.worklytics.client_id

  owners = var.owners
}

resource "azuread_application_federated_identity_credential" "worklytics" {
  count = var.worklytics_tenant_id == null ? 0 : 1

  application_id = azuread_application.worklytics.id
  display_name   = "${var.resource_name_prefix}federated-identity"
  description    = var.federated_identity_description
  audiences      = [local.federated_identity_audience]
  issuer         = var.federated_identity_issuer
  subject        = var.worklytics_tenant_id
}

# Read/write blobs in the export container (Worklytics export + overwrite).
# azuread v3 exports .id as the Graph path (/servicePrincipals/{guid}); Azure RBAC
# principal_id must be the object ID GUID.
resource "azurerm_role_assignment" "role_contributor" {
  scope                            = local.storage_container_resource_manager_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.worklytics.object_id
  skip_service_principal_aad_check = true
}

# User Delegation Key via Azure SDK (account-level; keys cannot be requested at container scope).
resource "azurerm_role_assignment" "role_delegator" {
  scope                            = local.storage_account_id
  role_definition_name             = "Storage Blob Delegator"
  principal_id                     = azuread_service_principal.worklytics.object_id
  skip_service_principal_aad_check = true
}

locals {
  tenant_identity_note = var.worklytics_tenant_sa_email == null ? (
    var.worklytics_tenant_id == null ? "(not configured; pre-production)" : var.worklytics_tenant_id
  ) : "${var.worklytics_tenant_sa_email} (${var.worklytics_tenant_id})"

  todo_content = <<EOT
# Configure Data Export in Worklytics

1. Ensure you're authenticated with Worklytics. Either sign-in at [https://${var.worklytics_host}](https://${var.worklytics_host})
  with your organization's SSO provider *or* request OTP link from your Worklytics support.
2. Visit `https://${var.worklytics_host}/analytics/data-export/connect?type=AZURE_BLOB_STORAGE&container=${local.storage_container_name}&storageAccount=${local.storage_account_name}&clientId=${azuread_application.worklytics.client_id}&tenantId=${var.azure_tenant_id}`
3. Review any additional settings (such as the Dataset type you'd like to export) and adjust
  values as you see fit, then click "Create Data Export".

Alternatively, you may follow the manual instructions below:

1. Visit [https://${var.worklytics_host}/analytics/data-export](https://${var.worklytics_host}/analytics/data-export)
  (or login into Worklytics, and navigate to Manage --> Export Data).
2. Click on the 'Create New Data Export' button in the upper right.
3. Fill in the form with the following values:
  - **Data Export Name** - choose a name that will help you identify this export in the future.
  - **Data Export Type** - choose the type of data you'd like to export. Check our
    [Data Export Documentation](https://${var.worklytics_host}/docs/data-export) for a complete
    description of all the available datasets.
  - **Data Destination** - choose 'Azure Blob Storage', and use the following values for each field:
    - Container Name: ${local.storage_container_name}
    - Storage Account: ${local.storage_account_name}
    - Client ID: ${azuread_application.worklytics.client_id}
    - Tenant ID: ${var.azure_tenant_id}
    - Worklytics tenant identity: ${local.tenant_identity_note}
EOT
}

resource "local_file" "todo" {
  count = var.todos_as_local_files ? 1 : 0

  filename = "TODO - configure export in worklytics.md"
  content  = local.todo_content
}
