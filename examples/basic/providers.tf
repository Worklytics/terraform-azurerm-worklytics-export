terraform {
  # Local state is convenient for iterating on this repo and for GitHub Actions e2e.
  # Do NOT use a local backend in production; use remote state (Terraform Cloud, azurerm,
  # GCS, S3, etc.) so state is shared, locked, and backed up.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    # Storage accounts, blob containers, and Azure RBAC (role assignments).
    # Floor 4.0: containers are managed via storage_account_id (Resource Manager API).
    # 3.x used storage_account_name / data-plane APIs, which 4.x deprecated.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    # Entra ID (Azure AD): application, service principal, and federated identity
    # credential (Google → Entra WIF). HashiCorp splits this from azurerm; both are
    # required. There is no azurerm resource for federated identity credentials.
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.47"
    }
  }
}

# In real use you likely already have these provider blocks in the root module.
provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}
