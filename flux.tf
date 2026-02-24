resource "kubernetes_namespace" "flux_system_namespace" {
  count = var.enable_flux ? 1 : 0
  metadata {
    name = "flux-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubernetes_secret" "flux_github_app" {
  count = var.enable_flux ? 1 : 0
  metadata {
    name      = "flux-github-app-secret"
    namespace = kubernetes_namespace.flux_system_namespace[0].metadata.0.name
  }

  data = {
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.cpp_github_app
  }

  type = "Opaque"
}

resource "helm_release" "flux2" {
  count      = var.enable_flux ? 1 : 0
  name       = lookup(var.charts.flux2, "name", "flux2")
  chart      = lookup(var.charts.flux2, "name", "flux2")
  version    = lookup(var.charts.flux2, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.flux_system_namespace[0].metadata.0.name

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.flux_system_namespace
  ]
}
