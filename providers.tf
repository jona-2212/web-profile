terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# AWS Provider – uses credentials from `aws configure` (AWS Academy)
provider "aws" {
  region = var.aws_region
}

# GitHub Provider – uses Personal Access Token
# Required token scopes: repo, admin:repo_hook
provider "github" {
  token = var.github_token
  owner = var.github_owner
}
