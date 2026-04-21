resource "kubernetes_namespace" "eck_namespace" {
  count = var.eck_operator_config.enable ? 1 : 0
  metadata {
    name = "elastic-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "disabled"
    }
  }
  lifecycle {
    ignore_changes = [metadata[0].labels["dynakube.internal.dynatrace.com/instance"]]
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubectl_manifest.dynatrace_cr_install
  ]
}

resource "helm_release" "eck_operator" {
  count      = var.eck_operator_config.enable ? 1 : 0
  name       = lookup(var.charts["eck-operator"], "name", "elastic-operator")
  chart      = lookup(var.charts["eck-operator"], "name", "eck-operator")
  version    = lookup(var.charts["eck-operator"], "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.eck_namespace[0].metadata.0.name

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/docker.elastic.co/eck/eck-operator"
  }

  set {
    name  = "image.tag"
    value = var.eck_operator_config.image_tag
  }

  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_namespace.eck_namespace
  ]
}
