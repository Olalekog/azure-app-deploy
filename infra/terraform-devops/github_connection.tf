# Azure Pipelines requires a GitHub service connection to create GitHub-sourced pipeline
# definitions and set up their push-trigger webhooks - true even for a public repo like this one.
# Unlike the AzureTraining service connection, this doesn't need any Entra ID permissions, just a
# GitHub PAT you control, so it's safe to fully automate.
resource "azuredevops_serviceendpoint_github" "this" {
  project_id            = data.azuredevops_project.this.id
  service_endpoint_name = "GitHub"

  auth_personal {
    personal_access_token = var.github_personal_access_token
  }
}
