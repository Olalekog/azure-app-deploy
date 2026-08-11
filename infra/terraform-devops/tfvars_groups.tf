# Input values infra-deploy.yml needs to reconstruct infra/terraform/terraform.tfvars and
# backend.hcl at pipeline runtime, replacing the old Secure File uploads. Separate from
# variable_groups.tf's todoapp-staging/todoapp-production (which hold that same infra's
# *outputs*, read from remote state) since these are needed *before* the infra exists - keeping
# them apart avoids a circular dependency between the two.

resource "azuredevops_variable_group" "staging_tfvars" {
  project_id   = data.azuredevops_project.this.id
  name         = "todoapp-staging-tfvars"
  description  = "Managed by infra/terraform-devops - edit tfvars and re-apply, not the UI."
  allow_access = true

  variable {
    name  = "existingVnetName"
    value = var.staging_tfvars.existing_vnet_name
  }
  variable {
    name  = "frontendSubnetPrefix"
    value = var.staging_tfvars.frontend_subnet_prefix
  }
  variable {
    name  = "backendSubnetPrefix"
    value = var.staging_tfvars.backend_subnet_prefix
  }
  variable {
    name  = "backendLbPrivateIp"
    value = var.staging_tfvars.backend_lb_private_ip
  }
  variable {
    name  = "adminUsername"
    value = var.staging_tfvars.admin_username
  }
  variable {
    name         = "adminSshPublicKey"
    is_secret    = true
    secret_value = var.staging_tfvars.admin_ssh_public_key
  }
  variable {
    name  = "frontendInstanceCount"
    value = tostring(var.staging_tfvars.frontend_instance_count)
  }
  variable {
    name  = "frontendInstanceMax"
    value = tostring(var.staging_tfvars.frontend_instance_max)
  }
  variable {
    name  = "backendInstanceCount"
    value = tostring(var.staging_tfvars.backend_instance_count)
  }
  variable {
    name  = "backendInstanceMax"
    value = tostring(var.staging_tfvars.backend_instance_max)
  }
}

resource "azuredevops_variable_group" "production_tfvars" {
  project_id   = data.azuredevops_project.this.id
  name         = "todoapp-production-tfvars"
  description  = "Managed by infra/terraform-devops - edit tfvars and re-apply, not the UI."
  allow_access = true

  variable {
    name  = "existingVnetName"
    value = var.production_tfvars.existing_vnet_name
  }
  variable {
    name  = "frontendSubnetPrefix"
    value = var.production_tfvars.frontend_subnet_prefix
  }
  variable {
    name  = "backendSubnetPrefix"
    value = var.production_tfvars.backend_subnet_prefix
  }
  variable {
    name  = "backendLbPrivateIp"
    value = var.production_tfvars.backend_lb_private_ip
  }
  variable {
    name  = "adminUsername"
    value = var.production_tfvars.admin_username
  }
  variable {
    name         = "adminSshPublicKey"
    is_secret    = true
    secret_value = var.production_tfvars.admin_ssh_public_key
  }
  variable {
    name  = "frontendInstanceCount"
    value = tostring(var.production_tfvars.frontend_instance_count)
  }
  variable {
    name  = "frontendInstanceMax"
    value = tostring(var.production_tfvars.frontend_instance_max)
  }
  variable {
    name  = "backendInstanceCount"
    value = tostring(var.production_tfvars.backend_instance_count)
  }
  variable {
    name  = "backendInstanceMax"
    value = tostring(var.production_tfvars.backend_instance_max)
  }
}
