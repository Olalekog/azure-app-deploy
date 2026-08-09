data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "key_vault" {
  name = coalesce(var.key_vault_resource_group_name, var.existing_resource_group_name)
}

resource "azurerm_key_vault" "this" {
  name                      = var.key_vault_name
  resource_group_name       = data.azurerm_resource_group.key_vault.name
  location                  = data.azurerm_resource_group.key_vault.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = false
  tags                      = var.tags
}

# Under RBAC authorization, creating the vault grants the caller no data-plane access - without
# this, the secret write below fails with 403. Azure DevOps' own read access is granted
# separately, further down.
resource "azurerm_role_assignment" "terraform_caller_kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignments can take up to a minute or two to actually be enforced - without this pause,
# the secret write below can still 403 even though the assignment above already "succeeded".
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.terraform_caller_kv_secrets_officer]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "azure_service_connection" {
  name         = "azureServiceConnection"
  value        = var.azure_training_service_connection_name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# Persisted for reuse by pipelines/scripts that need this ID later - Terraform itself still takes
# it as a plain input (azure_training_sp_object_id), since it's needed *before* this vault - and
# any secret in it - can be read: it's what grants that same principal access to the vault in the
# first place. Storing it here doesn't remove that bootstrap step, it just avoids re-discovering
# the value by hand every time something downstream needs it.
resource "azurerm_key_vault_secret" "azure_training_sp_object_id" {
  name         = "azureTrainingSpObjectId"
  value        = var.azure_training_sp_object_id
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_key_vault_secret" "azdo_org_service_url" {
  name         = "azdoOrgServiceUrl"
  value        = var.azdo_org_service_url
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# Lets Azure DevOps' variable-group Key Vault link actually read the secrets above.
resource "azurerm_role_assignment" "azure_training_kv_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.azure_training_sp_object_id
}

data "azuredevops_serviceendpoint_azurerm" "azure_training" {
  project_id            = data.azuredevops_project.this.id
  service_endpoint_name = var.azure_training_service_connection_name
}

resource "azuredevops_variable_group" "azure_connection" {
  project_id   = data.azuredevops_project.this.id
  name         = "todoapp-azure-connection"
  description  = "Managed by infra/terraform-devops - Key Vault-linked, do not edit values in the UI."
  allow_access = true

  key_vault {
    name                = azurerm_key_vault.this.name
    service_endpoint_id = data.azuredevops_serviceendpoint_azurerm.azure_training.id
  }

  variable {
    name = "azureServiceConnection"
  }

  variable {
    name = "azureTrainingSpObjectId"
  }

  variable {
    name = "azdoOrgServiceUrl"
  }

  depends_on = [
    azurerm_key_vault_secret.azure_service_connection,
    azurerm_key_vault_secret.azure_training_sp_object_id,
    azurerm_key_vault_secret.azdo_org_service_url,
    azurerm_role_assignment.azure_training_kv_secrets_user,
  ]
}
