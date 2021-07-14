terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.46"
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
  }

  required_version = ">= 0.12"
}