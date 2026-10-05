# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - Unreleased

### Breaking Changes
- Removed `worklytics_tenant_sa_email` (federation and instructions use `worklytics_tenant_id` only).
- Removed `todos_as_local_files` and the module's `local_file` resource; use the `todo_markdown`
  output instead (see `examples/basic/` for writing it to disk).
- Removed `todos_as_outputs`; `todo_markdown` is always emitted.
- Dropped `hashicorp/local` from module provider requirements.

### Changed
- `storage_container_name` documents fixed container naming (create or reuse) and the existing-storage
  flow: set `storage_account_name` and `storage_container_name` to matching names before apply.

## [0.1.0] - Unreleased

### Added
- Initial module to set up an Azure Blob Storage destination for exporting data from Worklytics.
- Optional creation of a storage account and/or private blob container; existing names are reused
  when provided.
- Entra application, service principal, and Google → Entra federated identity credential keyed by
  the Worklytics tenant's 21-digit GCP service account unique ID. The credential is omitted when
  `worklytics_tenant_id` is `null` (pre-production review).
- `Storage Blob Data Contributor` on the container and `Storage Blob Delegator` on the account.
- Native `terraform test` unit tests (mocked providers) and a GitHub Actions integration test that
  applies the module in Azure and round-trips a blob as the federated GCP identity.
- Maintainer release helper (`tools/release.sh`) that tags `origin/main` only after required CI
  checks pass.
- Requires Terraform 1.3+, `azurerm` >= 4.0, and `azuread` >= 2.47.
