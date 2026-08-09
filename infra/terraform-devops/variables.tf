variable "existing_resource_group_name" {
  description = "Same pre-existing resource group used by the app infra stacks."
  type        = string
  default     = "Training-Batch-6.23"
}

variable "existing_storage_account_name" {
  description = "Same pre-existing, shared storage account used by the app infra stacks."
  type        = string
  default     = "olalekog"
}

variable "azdo_project_name" {
  description = "Azure DevOps project name that owns the pipelines/variable groups."
  type        = string
}

variable "azdo_org_service_url" {
  description = "Azure DevOps organization URL, published as a Library variable (azdoOrgServiceUrl, via todoapp-azure-connection) so pipelines don't need to hardcode it."
  type        = string
  default     = "https://dev.azure.com/324DSTraining"
}

variable "azure_training_service_connection_name" {
  description = "Name of the existing ARM service connection (created manually - see DEPLOY.md step 4)."
  type        = string
  default     = "AzureTraining"
}

variable "azure_training_sp_object_id" {
  description = "Entra ID object ID of the AzureTraining service connection's underlying service principal. Find it via: az ad sp show --id <appId> --query id -o tsv (appId comes from the service connection's 'Manage Service Principal' link in Azure DevOps)."
  type        = string
}

variable "key_vault_name" {
  description = "Name for the Key Vault this stack creates to hold the azureServiceConnection secret and back the todoapp-azure-connection variable group. Must be globally unique, 3-24 alphanumeric/hyphen characters."
  type        = string
}

variable "key_vault_resource_group_name" {
  description = "Resource group to create key_vault_name in, if different from existing_resource_group_name."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to resources this stack creates."
  type        = map(string)
  default = {
    project = "todoapp"
  }
}

# Published into todoapp-staging-tfvars / todoapp-production-tfvars (tfvars_groups.tf) so
# infra-deploy.yml can reconstruct infra/terraform/terraform.tfvars without Secure Files. These
# are *inputs* to the app infra (needed to create it), unlike todoapp-staging/todoapp-production
# (variable_groups.tf) which hold that infra's *outputs* - keeping them in separate groups avoids
# a circular dependency, since the output-holding groups can't be populated until the infra
# already exists, but these input values are needed before it does.
variable "staging_tfvars" {
  description = "Mirrors terraform.tfvars.staging.example - see infra/terraform/variables.tf for field meanings."
  type = object({
    existing_vnet_name      = string
    frontend_subnet_prefix  = string
    backend_subnet_prefix   = string
    backend_lb_private_ip   = string
    admin_username          = string
    admin_ssh_public_key    = string
    frontend_instance_count = number
    frontend_instance_max   = number
    backend_instance_count  = number
    backend_instance_max    = number
  })
}

variable "production_tfvars" {
  description = "Mirrors terraform.tfvars.production.example - see infra/terraform/variables.tf for field meanings."
  type = object({
    existing_vnet_name      = string
    frontend_subnet_prefix  = string
    backend_subnet_prefix   = string
    backend_lb_private_ip   = string
    admin_username          = string
    admin_ssh_public_key    = string
    frontend_instance_count = number
    frontend_instance_max   = number
    backend_instance_count  = number
    backend_instance_max    = number
  })
}
