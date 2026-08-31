# Worklytics Export to Azure Terraform Module

[![Latest Release](https://img.shields.io/github/v/release/Worklytics/terraform-azurerm-worklytics-export)](https://github.com/Worklytics/terraform-azurerm-worklytics-export/releases/latest)
[![tests](https://img.shields.io/github/actions/workflow/status/Worklytics/terraform-azurerm-worklytics-export/terraform_integration.yaml?label=tests)](https://github.com/Worklytics/terraform-azurerm-worklytics-export/actions?query=branch%3Amain)

This module creates infra to support exporting data from Worklytics to [Azure Blob Storage].

It is intended for the [Terraform Registry](https://registry.terraform.io/modules/Worklytics/worklytics-export/azurerm/latest)
(`Worklytics/worklytics-export/azurerm`).

If it does not meet your needs, feel free to directly copy the `main.tf` file into your own Terraform
configuration and adapt it to your requirements.

## What it provisions

1. **Optional storage** — an Azure storage account and/or blob container, unless you pass existing
   names. Created accounts use TLS 1.2, HTTPS-only, infrastructure encryption, shared access keys
   disabled, and `LRS` unless you override replication.
2. **Entra application + service principal** with a federated identity credential that trusts your
   Worklytics tenant's GCP service account (`issuer = https://accounts.google.com`,
   `subject = worklytics_tenant_id`).
3. **RBAC** so that identity can write blobs in the export container (`Storage Blob Data
   Contributor` on the container, `Storage Blob Delegator` on the account).

Worklytics then exchanges a Google ID token for an Entra access token and writes export objects
to the container.

## Usage

from Terraform registry (once published):
```hcl
module "worklytics-export" {
  source  = "Worklytics/worklytics-export/azurerm"
  version = "~> 0.1.0"

  # numeric ID of your Worklytics Tenant SA (21-digit unique ID, not the email)
  worklytics_tenant_id = "123456789012345678901"
  azure_tenant_id      = "11111111-1111-1111-1111-111111111111"
  resource_group_name  = "worklytics"
}
```

via GitHub:
```hcl
module "worklytics-export" {
  source = "git::https://github.com/worklytics/terraform-azurerm-worklytics-export/?ref=v0.1.0"

  worklytics_tenant_id = "123456789012345678901"
  azure_tenant_id      = "11111111-1111-1111-1111-111111111111"
  resource_group_name  = "worklytics"
}
```

The calling configuration must declare `azurerm` and `azuread` providers. This module does not
configure providers (so it can be composed into an existing Azure workspace).

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}
```

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `worklytics_tenant_id` | no | `null` | 21-digit unique ID of the Worklytics tenant GCP SA; `null` skips federation (pre-prod) |
| `azure_tenant_id` | yes | | Entra tenant ID (for instructions / deep-link) |
| `resource_group_name` | yes | | Existing resource group for the storage account |
| `storage_account_name` | no | `null` | Reuse this account; otherwise one is created |
| `storage_container_name` | no | `null` | Reuse this container; otherwise one is created |
| `account_replication_type` | no | `LRS` | Replication for a *created* account (`GRS` / `RAGRS` / `GZRS` / `RAGZRS` recommended in production) |
| `infrastructure_encryption_enabled` | no | `true` | Double-encrypt a *created* account (set at creation only) |
| `blob_diagnostics` | no | `null` | Azure Monitor destination for blob logs; omit to skip logging |
| `location` | no | RG location | Region used only when creating a storage account |
| `worklytics_tenant_sa_email` | no | `null` | SA email, documentation only |
| `resource_name_prefix` | no | `worklytics-export-` | Prefix for created Entra / container names |
| `owners` | no | `[]` | Entra object IDs set as owners of the application |
| `worklytics_host` | no | `app.worklytics.co` | Hostname for connect TODOs / deep-links (prod by default; override for a custom domain) |

Your Worklytics tenant identity is the **numeric unique ID** of the tenant's GCP service account
(the same value used by the AWS export and Azure import modules). The SA email cannot be used as
the federated credential subject. Obtain the ID from the Worklytics app, or:

```bash
gcloud iam service-accounts describe EMAIL --format='value(uniqueId)'
```

## Outputs

#### `storage_account_name` / `storage_account_id` / `storage_account_primary_blob_endpoint`
The storage account used as the export destination (created or reused).

#### `storage_container_name` / `storage_container_resource_manager_id`
The blob container Worklytics writes to. Compose with additional `azurerm_*` resources for
retention, extra RBAC, or a customer-managed key.

#### `blob_services_resource_id` / `blob_diagnostic_setting_id`
`blob_services_resource_id` is the ARM id of the account blob service
(`…/blobServices/default`). Pass it as `target_resource_id` on your own
`azurerm_monitor_diagnostic_setting` if you do not set `blob_diagnostics`.
`blob_diagnostic_setting_id` is set only when the module creates that setting.

#### `account_replication_type` / `infrastructure_encryption_enabled`
Values for an account *created* by this module; `null` when you reuse an existing account
(configure those on the existing account, or pass a hardened account in).

#### `application_client_id`
Entra application (client) ID. Worklytics uses this when exchanging a Google ID token for an Azure
access token.

#### `service_principal_object_id`
Object ID of the service principal granted blob access. Compose with additional `azurerm_role_assignment`
resources if you use a customer-managed encryption key or extra locks.

#### `connect_url`
Deep-link to finish setup in Worklytics (`https://app.worklytics.co/analytics/data-export/connect?...`
unless you set `worklytics_host`).

#### `todo_markdown`
Rendered when `todos_as_outputs = true`.

## Compatibility

This module is meant for use with Terraform 1.3+ and:

- `azurerm` `>= 4.0` (storage + Azure RBAC)
- `azuread` `>= 2.47` (Entra app, service principal, federated identity credential)

Both providers are required: HashiCorp splits Azure Resource Manager from Entra ID. This module
does not configure provider blocks; the caller must.

If you find incompatibilities, please open an issue.

## Usage Tips

### Existing storage account / container

Pass both names to skip storage creation and only grant Worklytics access:

```hcl
module "worklytics-export" {
  source = "Worklytics/worklytics-export/azurerm"

  worklytics_tenant_id   = "123456789012345678901"
  azure_tenant_id        = "11111111-1111-1111-1111-111111111111"
  resource_group_name    = "worklytics"
  storage_account_name   = "myexistingaccount"
  storage_container_name = "worklytics-export"
}
```

If you omit only `storage_container_name`, the module creates a private container on the existing
account.

### Logging, encryption, and replication

These apply only to a storage account **created** by the module. If you pass
`storage_account_name`, configure them on that account (or compose extra resources using the
outputs below).

**Infrastructure encryption** is on by default for created accounts (`infrastructure_encryption_enabled = true`).
It can only be set at creation. **Shared access keys** are disabled (`shared_access_key_enabled = false`);
Worklytics uses Entra workload identity federation, not account keys.

**Replication** defaults to `LRS`. For production durability use geo-redundant storage:

```hcl
module "worklytics-export" {
  source = "Worklytics/worklytics-export/azurerm"
  # ...
  account_replication_type = "GRS" # or RAGRS, GZRS, RAGZRS
}
```

**Blob logging** needs a destination you already own (Log Analytics workspace, another storage
account, or Event Hub). It is off until you pass one:

```hcl
module "worklytics-export" {
  source = "Worklytics/worklytics-export/azurerm"
  # ...
  blob_diagnostics = {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  }
}
```

Or compose the diagnostic setting yourself (same destination types):

```hcl
resource "azurerm_monitor_diagnostic_setting" "export_blobs" {
  name                       = "worklytics-export-blobs"
  target_resource_id         = module.worklytics-export.blob_services_resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

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
```

Do not send diagnostics to the export storage account itself.

### Permissions granted to Worklytics

| Role | Scope | Why |
|------|-------|-----|
| Storage Blob Data Contributor | container | Write/overwrite export blobs |
| Storage Blob Delegator | storage account | User delegation keys used by Azure SDKs |

The federated credential trusts Google (`accounts.google.com`) as issuer and your
`worklytics_tenant_id` as subject, with audience `api://AzureADTokenExchange`.

## Development

This module is written and maintained by [Worklytics, Co.](https://worklytics.co/) and intended to
guide our customers in setting up their own infra to export data from Worklytics to Azure Blob
Storage.

As this is [published as a Terraform module](https://developer.hashicorp.com/terraform/registry/modules/publish),
we will strive to follow [standard Terraform module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
and [style conventions](https://developer.hashicorp.com/terraform/language/syntax/style).

See [examples/basic/](examples/basic/) for a simple example of how to use this module.

### Releasing

Registry versions are **git tags** (`vX.Y.Z`) on `main`, not GitHub Releases. After a change is on
`main` and CI is green:

```bash
./tools/release.sh v0.1.0 --wait
```

That tags the current `origin/main` commit and pushes the tag. The tag-triggered workflow creates
the GitHub Release (notes / README badge). First-time listing on
[registry.terraform.io](https://registry.terraform.io/modules/Worklytics/worklytics-export/azurerm)
is a one-time Publish in the HashiCorp UI (`Worklytics/worklytics-export/azurerm`); later tags are
picked up by the Registry webhook.

### Tests

| Workflow | What it covers |
|----------|----------------|
| `terraform_lint.yaml` | `terraform fmt -check` |
| `terraform_validate.yaml` | `terraform init` / `validate` on `examples/basic`, plus `terraform test` unit tests |
| `terraform_integration.yaml` | Apply in a CI Azure subscription, then read/write a blob as the stand-in Worklytics GCP identity |
| `terraform_security.yaml` | Trivy IaC scan |

Unit tests live in [`tests/`](tests/) and use Terraform's native test framework with mocked
`azurerm` / `azuread` providers (no cloud credentials).

Integration tests authenticate to **Azure** (GitHub → Entra OIDC) to apply this module, and to
**GCP** (GitHub → WIF) to impersonate the stand-in Worklytics tenant SA. The test then exchanges a
Google ID token, logs in with `az --federated-token`, and uploads/downloads a blob. Required GitHub
secrets (public repo) or variables (private repo):

| Name | Purpose |
|------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GitHub Actions WIF provider |
| `GCP_SERVICE_ACCOUNT` | CI agent SA (e.g. `gh-actions-tf-azure-export@...`) |
| `ENTRA_ID_CLIENT_ID` | Entra app for GitHub OIDC |
| `ENTRA_ID_TENANT_ID` | Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Subscription that contains the CI resource group |
| `AZURE_RESOURCE_GROUP_NAME` | Pre-created sandbox resource group (Owner scoped to this RG) |

The CI agent SA must be able to impersonate the stand-in tenant SA
(`w8s-export-tf-ci-tenant@worklytics-ci.iam.gserviceaccount.com`, shared with GCP export CI). The
Entra GitHub OIDC app must be able to create storage accounts, Entra applications, and role
assignments **in the CI resource group** (not subscription-wide). The resource group is provisioned
by `worklytics-infra` (`src/org-github`) and is delete-locked; workflows must not create or delete
it. Expected name: `rg-w8s-tf-azure-export-ci`.

(c) 2026 Worklytics, Co

[Azure Blob Storage]: https://learn.microsoft.com/en-us/azure/storage/blobs/
