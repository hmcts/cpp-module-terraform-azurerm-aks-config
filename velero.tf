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
