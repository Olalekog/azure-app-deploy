terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Separate state from the app infra stacks - see backend.hcl.example.
  backend "azurerm" {}
}

provider "azuredevops" {
  # Reads AZDO_ORG_SERVICE_URL and AZDO_PERSONAL_ACCESS_TOKEN from the environment.
  # Never put a PAT in a .tf/.tfvars file - see DEPLOY.md.
}

provider "azurerm" {
  features {}
}
