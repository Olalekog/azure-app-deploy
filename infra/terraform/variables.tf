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

variable "location" {
  description = "Azure region to deploy into."
  type        = string
  default     = "eastus"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "frontend_subnet_prefix" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "backend_subnet_prefix" {
  type    = list(string)
  default = ["10.20.2.0/24"]
}

variable "backend_lb_private_ip" {
  description = "Static private IP for the internal (backend) Standard Load Balancer. Must fall inside backend_subnet_prefix."
  type        = string
  default     = "10.20.2.4"
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
