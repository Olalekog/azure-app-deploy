# Creates all six pipeline definitions pointing at their YAML files in this repo. Each pipeline's
# own trigger:/paths: block already controls when it runs (ci_trigger.use_yaml delegates to
# that), so nothing here duplicates that config.
locals {
  pipeline_repository = {
    repo_type   = "GitHub"
    repo_id     = var.github_repo_id
    branch_name = var.github_branch_name
  }
}

resource "azuredevops_build_definition" "frontend_build" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-frontend-build"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/frontend-build.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }
}

resource "azuredevops_build_definition" "frontend_release" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-frontend-release"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/frontend-release.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }

  # Not a functional dependency (frontend-release.yml resolves "todoapp-frontend-build" by name
  # at run time, not at definition-creation time) - just keeps creation order matching intent.
  depends_on = [azuredevops_build_definition.frontend_build]
}

resource "azuredevops_build_definition" "backend_build" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-backend-build"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/backend-build.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }
}

resource "azuredevops_build_definition" "backend_release" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-backend-release"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/backend-release.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }

  depends_on = [azuredevops_build_definition.backend_build]
}

resource "azuredevops_build_definition" "infra_deploy" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-infra-deploy"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/infra-deploy.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }
}

resource "azuredevops_build_definition" "devops_deploy" {
  project_id = data.azuredevops_project.this.id
  name       = "todoapp-devops-deploy"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = local.pipeline_repository.repo_type
    repo_id               = local.pipeline_repository.repo_id
    branch_name           = local.pipeline_repository.branch_name
    yml_path              = "pipelines/devops-deploy.yml"
    service_connection_id = azuredevops_serviceendpoint_github.this.id
  }
}
