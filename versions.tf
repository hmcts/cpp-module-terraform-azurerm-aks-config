terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.46"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3.2"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.2.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.11.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 2.21.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.1.0"
    }

    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }

  required_version = ">= 0.12"
}