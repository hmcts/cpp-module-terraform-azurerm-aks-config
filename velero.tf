resource "azurerm_storage_account" "storage_account_velero" {
  count                     = var.velero_config.enable ? 1 : 0
  name                      = replace(lower("SA-${var.aks_cluster_name}"), "-", "")
  resource_group_name       = var.aks_resource_group_name
  location                  = var.aks_cluster_location
  account_tier              = var.velero_config.account_tier
  is_hns_enabled            = true
  account_replication_type  = var.velero_config.account_replication_type
  tags                      = var.tags
  enable_https_traffic_only = true
}

resource "kubernetes_namespace" "velero_namespace" {
  count = var.velero_config.enable ? 1 : 0
  metadata {
    name = "velero"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "disabled"
      "istio-injection"              = "disabled"
    }
  }
}

data "vault_generic_secret" "azure_app_secret" {
  path = "secret/mgmt/azure_app_secret"
}

locals {
  azCreds = {
    cloud = <<EOT
      AZURE_SUBSCRIPTION_ID=${data.azurerm_client_config.current.subscription_id}
      AZURE_TENANT_ID=${data.azurerm_client_config.current.tenant_id}
      AZURE_CLIENT_ID=${data.azurerm_client_config.current.client_id}
      AZURE_CLIENT_SECRET=${data.vault_generic_secret.azure_app_secret.data.value}
      AZURE_RESOURCE_GROUP=${data.azurerm_kubernetes_cluster.aks_cluster.node_resource_group}
      AZURE_CLOUD_NAME="AzurePublicCloud"
    EOT
  }
}

resource "helm_release" "velero_install" {
  count      = var.velero_config.enable ? 1 : 0
  name       = lookup(var.charts.velero, "name", "velero")
  chart      = lookup(var.charts.velero, "name", "velero")
  version    = lookup(var.charts.velero, "version", "")
  repository = "./install"
  namespace  = "velero"

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/velero/velero"
  }
  set {
    name  = "initContainers[0].image"
    value = "${var.acr_name}.azurecr.io/docker.io/velero/velero-plugin-for-microsoft-azure:v1.6.0-rc.1"
  }
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-microsoft-azure"
  }
  set {
    name  = "credentials.secretContents.cloud"
    value = local.azCreds.cloud
  }
#  set {
#    name  = "credentials.secretContents.cloud.AZURE_TENANT_ID"
#    value = local.azCreds.cloud.AZURE_TENANT_ID
#  }
#  set {
#    name  = "credentials.secretContents.cloud.AZURE_CLIENT_ID"
#    value = local.azCreds.cloud.AZURE_CLIENT_ID
#  }
#  set {
#    name  = "credentials.secretContents.cloud.AZURE_CLIENT_SECRET"
#    value = local.azCreds.cloud.AZURE_CLIENT_SECRET
#  }
#  set {
#    name  = "credentials.secretContents.cloud.AZURE_RESOURCE_GROUP"
#    value = local.azCreds.cloud.AZURE_RESOURCE_GROUP
#  }
#  set {
#    name  = "credentials.secretContents.cloud.AZURE_CLOUD_NAME"
#    value = local.azCreds.cloud.AZURE_CLOUD_NAME
#  }
  set {
    name  = "configuration.provider"
    value = "azure"
  }
  set {
    name  = "configuration.provider.backupStorageLocation.bucket"
    value = var.aks_cluster_name
  }
  set {
    name  = "configuration.provider.backupStorageLocation.caCert"
    value = filebase64(var.ca_bundle_path)
  }
  set {
    name  = "configuration.provider.backupStorageLocation.config.storageAccount"
    value = azurerm_storage_account.storage_account_velero.0.name
  }
  set {
    name  = "configuration.provider.backupStorageLocation.config.resourceGroup"
    value = var.aks_resource_group_name
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.velero_namespace
  ]
}
