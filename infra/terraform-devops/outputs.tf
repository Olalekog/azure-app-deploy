output "staging_variable_group_id" {
  value = azuredevops_variable_group.staging.id
}

output "production_variable_group_id" {
  value = azuredevops_variable_group.production.id
}

output "azure_connection_variable_group_id" {
  value = azuredevops_variable_group.azure_connection.id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}
