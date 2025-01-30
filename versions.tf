terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.2.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.4"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 2.21.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.1.0"
    }
  }

  required_version = ">= 0.12"
}
