# Approval/audit anchors for the release and infra pipelines' gated stages - resource type
# "None" (no Kubernetes/VM resources attached), matching what was previously created by hand.
resource "azuredevops_environment" "staging" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-staging"
}

resource "azuredevops_environment" "production" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-production"
}

resource "azuredevops_environment" "devops" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-devops"
}

# RBAC-backed approval gate: only approver_object_id can approve promotion to production, or
# changes to the Library/Key Vault config devops-deploy.yml applies. This is the gate that
# actually restricts *who* can approve - the ManualValidation task in each pipeline's YAML is
# just a backstop that pauses for anyone, not a replacement for this.
resource "azuredevops_check_approval" "production" {
  project_id           = data.azuredevops_project.this.id
  target_resource_type = "environment"
  target_resource_id   = azuredevops_environment.production.id
  approvers            = [var.approver_object_id]
}

resource "azuredevops_check_approval" "devops" {
  project_id           = data.azuredevops_project.this.id
  target_resource_type = "environment"
  target_resource_id   = azuredevops_environment.devops.id
  approvers            = [var.approver_object_id]
}
