resource "kubernetes_secret" "flux_github_app" {
  count = var.enable_flux ? 1 : 0
  metadata {
    name      = "flux-github-app-secret"
    namespace = var.flux_namespace
  }

  data = {
    app-id          = var.github_app_id
    installation-id = var.github_app_installation_id
    private-key.pem = var.github_app_private_key
  }

  type = "Opaque"
}


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
    local_auth_reference = var.enable_flux ? kubernetes_secret.flux_github_app.metadata[0].name : null
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
