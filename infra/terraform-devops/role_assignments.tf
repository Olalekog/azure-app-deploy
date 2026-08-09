# Grants the AzureTraining service connection's identity access to just the four release
# containers it needs to upload to - not the whole shared storage account. Replaces the manual
# `az role assignment create` loop previously documented in DEPLOY.md.

data "azurerm_storage_account" "shared" {
  name                = var.existing_storage_account_name
  resource_group_name = var.existing_resource_group_name
}

resource "azurerm_role_assignment" "release_container_access" {
  for_each = toset([
    data.terraform_remote_state.staging.outputs.frontend_release_container,
    data.terraform_remote_state.staging.outputs.backend_release_container,
    data.terraform_remote_state.production.outputs.frontend_release_container,
    data.terraform_remote_state.production.outputs.backend_release_container,
  ])

  scope                = "${data.azurerm_storage_account.shared.id}/blobServices/default/containers/${each.value}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.azure_training_sp_object_id
}
