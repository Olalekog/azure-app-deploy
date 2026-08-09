# Reuses a pre-existing, shared storage account (e.g. a training-subscription account you don't
# have permission to create more of) rather than provisioning a new one. It backs two things,
# with share/container names suffixed per environment since staging and production share this
# one account:
#   1. Azure Files share "tododata-<environment>" - shared JSON data tier, mounted via SMB on
#      every backend instance.
#   2. Blob containers "frontend-releases-<environment>" / "backend-releases-<environment>" -
#      release artifacts published by the Azure DevOps pipelines and pulled onto instances by the
#      cloud-init deploy scripts.
data "azurerm_storage_account" "main" {
  name                = var.existing_storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_storage_share" "tododata" {
  name                 = "tododata-${var.environment}"
  storage_account_name = data.azurerm_storage_account.main.name
  quota                = 10
}

resource "azurerm_storage_container" "frontend_releases" {
  name                  = "frontend-releases-${var.environment}"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backend_releases" {
  name                  = "backend-releases-${var.environment}"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "private"
}
