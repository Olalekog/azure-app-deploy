data "azuredevops_project" "this" {
  name = var.azdo_project_name
}

resource "azuredevops_variable_group" "staging" {
  project_id   = data.azuredevops_project.this.id
  name         = "todoapp-staging"
  description  = "Managed by infra/terraform-devops - edit tfvars and re-apply, not the UI."
  allow_access = true

  variable {
    name  = "resourceGroupName"
    value = data.terraform_remote_state.staging.outputs.resource_group_name
  }
  variable {
    name  = "storageAccountName"
    value = data.terraform_remote_state.staging.outputs.storage_account_name
  }
  variable {
    name  = "frontendVmssName"
    value = data.terraform_remote_state.staging.outputs.frontend_vmss_name
  }
  variable {
    name  = "backendVmssName"
    value = data.terraform_remote_state.staging.outputs.backend_vmss_name
  }
  variable {
    name  = "frontendReleaseContainer"
    value = data.terraform_remote_state.staging.outputs.frontend_release_container
  }
  variable {
    name  = "backendReleaseContainer"
    value = data.terraform_remote_state.staging.outputs.backend_release_container
  }
}

resource "azuredevops_variable_group" "production" {
  project_id   = data.azuredevops_project.this.id
  name         = "todoapp-production"
  description  = "Managed by infra/terraform-devops - edit tfvars and re-apply, not the UI."
  allow_access = true

  variable {
    name  = "resourceGroupName"
    value = data.terraform_remote_state.production.outputs.resource_group_name
  }
  variable {
    name  = "storageAccountName"
    value = data.terraform_remote_state.production.outputs.storage_account_name
  }
  variable {
    name  = "frontendVmssName"
    value = data.terraform_remote_state.production.outputs.frontend_vmss_name
  }
  variable {
    name  = "backendVmssName"
    value = data.terraform_remote_state.production.outputs.backend_vmss_name
  }
  variable {
    name  = "frontendReleaseContainer"
    value = data.terraform_remote_state.production.outputs.frontend_release_container
  }
  variable {
    name  = "backendReleaseContainer"
    value = data.terraform_remote_state.production.outputs.backend_release_container
  }
}
