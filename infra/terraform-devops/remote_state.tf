# Reads the outputs of the two app infra applies (../terraform, run with
# terraform.tfvars.staging.example / .production.example) out of their remote state - this stack
# has no direct dependency on those .tf files, just on the state they leave behind, so both must
# already be applied before this stack can be applied.

data "terraform_remote_state" "staging" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.existing_resource_group_name
    storage_account_name = var.existing_storage_account_name
    container_name       = "tfstate"
    key                  = "todoapp-staging.tfstate"
  }
}

data "terraform_remote_state" "production" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.existing_resource_group_name
    storage_account_name = var.existing_storage_account_name
    container_name       = "tfstate"
    key                  = "todoapp-production.tfstate"
  }
}
