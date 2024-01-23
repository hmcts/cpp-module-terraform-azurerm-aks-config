resource "kubernetes_namespace" "keda_namespace" {
  count = var.keda_config.enable ? 1 : 0
  metadata {
    name = "keda"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "disabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}



resource "helm_release" "keda_install" {
  count      = var.keda_config.enable ? 1 : 0
  name       = lookup(var.charts.keda, "name", "keda")
  chart      = lookup(var.charts.keda, "name", "keda")
  version    = lookup(var.charts.keda, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.keda_namespace[0].metadata.0.name

  set {
    name  = "image.keda.repository"
    value = "${var.acr_name}.azurecr.io/ghcr.io/kedacore/keda"
  }
  set {
    name  = "image.keda.tag"
    value = var.keda_config.image_tag
  }
  set {
    name  = "image.metricsApiServer.repository"
    value = "${var.acr_name}.azurecr.io/ghcr.io/kedacore/keda-metrics-apiserver"
  }
  set {
    name  = "image.metricsApiServer.tag"
    value = var.keda_config.image_tag
  }

  set {
    name  = "image.webhooks.repository"
    value = "${var.acr_name}.azurecr.io/ghcr.io/kedacore/keda-admission-webhooks"
  }
  set {
    name  = "image.webhooks.tag"
    value = var.keda_config.image_tag
  }


  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_namespace.keda_namespace
  ]
}
