# Explicit "open access to all pipelines" grants for each variable group. `allow_access = true`
# on azuredevops_variable_group is supposed to achieve this on its own, but some Azure DevOps
# organizations don't reliably honor it. This expresses the same setting through the lower-level
# pipeline-permissions API instead (pipeline_id omitted = authorized for every pipeline in the
# project, not just one), which is enforced more consistently.
resource "azuredevops_pipeline_authorization" "staging" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.staging.id
  type        = "variablegroup"
}

resource "azuredevops_pipeline_authorization" "production" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.production.id
  type        = "variablegroup"
}

resource "azuredevops_pipeline_authorization" "staging_tfvars" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.staging_tfvars.id
  type        = "variablegroup"
}

resource "azuredevops_pipeline_authorization" "production_tfvars" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.production_tfvars.id
  type        = "variablegroup"
}

resource "azuredevops_pipeline_authorization" "azure_connection" {
  project_id  = data.azuredevops_project.this.id
  resource_id = azuredevops_variable_group.azure_connection.id
  type        = "variablegroup"
}
