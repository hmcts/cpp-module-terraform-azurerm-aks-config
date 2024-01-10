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

resource "azurerm_storage_container" "blob" {
  count                 = var.velero_config.enable ? 1 : 0
  name                  = replace(lower("${var.aks_cluster_name}"), "-", "")
  storage_account_name  = azurerm_storage_account.storage_account_velero.0.name
  container_access_type = "private"
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
    value = "${var.acr_name}.azurecr.io/docker.io/velero/velero-plugin-for-microsoft-azure:v1.8.2"
  }
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-microsoft-azure"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }
  set {
    name  = "credentials.secretContents.cloud"
    value = local.azCreds.cloud
  }
  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "azure"
  }
  set {
    name  = "configuration.volumeSnapshotLocation[0].provider"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = replace(lower("${var.aks_cluster_name}"), "-", "")
  }
  set {
    name  = "configuration.backupStorageLocation[0].caCert"
    value = data.vault_generic_secret.ca_cert.data.issuing_ca
  }
  set {
    name  = "configuration.backupStorageLocation[0].config.storageAccount"
    value = azurerm_storage_account.storage_account_velero.0.name
  }
  set {
    name  = "configuration.backupStorageLocation[0].config.resourceGroup"
    value = var.aks_resource_group_name
  }
  set {
    name  = "resources.limits.cpu"
    value = "2000m"
  }
  set {
    name  = "resources.limits.memory"
    value = "1024Mi"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.velero_namespace
  ]
}
