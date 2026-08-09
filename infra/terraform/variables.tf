variable "project" {
  description = "Short project name used as a prefix for resource names."
  type        = string
  default     = "todoapp"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "existing_resource_group_name" {
  description = "Name of the pre-existing resource group to deploy into (this stack does not create its own resource group - e.g. a shared training-subscription RG). All new resources use this RG's region."
  type        = string
}

variable "existing_storage_account_name" {
  description = "Name of the pre-existing storage account to use for the Azure Files data share and release blob containers (this stack does not create its own storage account). Must be in existing_resource_group_name. Shared across environments - share/container names are suffixed with `environment` to avoid collisions."
  type        = string
}

variable "existing_vnet_name" {
  description = "Name of the pre-existing VNet to deploy subnets into (this stack does not create its own VNet)."
  type        = string
  default     = "VM-VNET"
}

variable "existing_vnet_resource_group_name" {
  description = "Resource group containing existing_vnet_name, if different from existing_resource_group_name."
  type        = string
  default     = null
}

variable "frontend_subnet_prefix" {
  description = "CIDR for this environment's frontend subnet. Must fall inside existing_vnet_name's address space, and must not overlap the other environment's subnets - they now share one VNet, unlike a per-environment VNet where the default could safely repeat. No default on purpose: check the VNet's real address space first (az network vnet show --name VM-VNET -g <rg> --query addressSpace -o jsonc) rather than guessing."
  type        = list(string)
}

variable "backend_subnet_prefix" {
  description = "CIDR for this environment's backend subnet. Same non-overlap caveat as frontend_subnet_prefix."
  type        = list(string)
}

variable "backend_lb_private_ip" {
  description = "Static private IP for the internal (backend) Standard Load Balancer. Must fall inside backend_subnet_prefix, and must differ between environments sharing the same VNet."
  type        = string
}

variable "admin_username" {
  description = "Admin username for VMSS instances."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key content used to provision VMSS instances. Instances have no public IP; use Azure Bastion or `az vmss run-command invoke` for access."
  type        = string
}

variable "frontend_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "backend_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "frontend_instance_count" {
  description = "Default/min instance count for the frontend scale set."
  type        = number
  default     = 2
}

variable "frontend_instance_max" {
  type    = number
  default = 5
}

variable "backend_instance_count" {
  description = "Default/min instance count for the backend scale set."
  type        = number
  default     = 2
}

variable "backend_instance_max" {
  type    = number
  default = 5
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project = "todoapp"
  }
}
