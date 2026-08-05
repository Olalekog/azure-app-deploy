# Storage account backs two things:
#   1. Azure Files share "tododata" - shared JSON data tier, mounted via SMB on every backend instance.
#   2. Blob containers "frontend-releases" / "backend-releases" - release artifacts published by the
#      Azure DevOps pipelines and pulled onto instances by the cloud-init deploy scripts.
resource "azurerm_storage_account" "main" {
  name                     = "st${replace(var.project, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_share" "tododata" {
  name                 = "tododata"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 10
}

resource "azurerm_storage_container" "frontend_releases" {
  name                  = "frontend-releases"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backend_releases" {
  name                  = "backend-releases"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
