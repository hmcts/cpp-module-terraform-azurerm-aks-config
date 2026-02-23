resource "azurerm_kubernetes_cluster_extension" "flux-extension" {
  count = var.enable_flux ? 1 : 0

  name           = var.extension_name
  cluster_id     = data.azurerm_kubernetes_cluster.aks_cluster.id
  extension_type = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "example" {
  for_each   = var.enable_flux ? var.kustomizations_cluster_config : {}
  name       = "${each.key}-flux-configuration"
  cluster_id = data.azurerm_kubernetes_cluster.aks_cluster.id
  namespace  = var.flux_namespace
  scope      = "cluster"

  git_repository {
    url             = "https://github.com/hmcts/cpp-flux-config"
    reference_type  = "branch"
    reference_value = "main"
  }

  kustomizations {
    name = "${each.key}-clusters"
    path = each.value.clusters_path
  }
  kustomizations {
    name = "${each.key}-apps"
    path = "./app"
  }


  depends_on = [
    azurerm_kubernetes_cluster_extension.flux-extension
  ]
}
