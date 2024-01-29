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

  set {
    name  = "podIdentity.azureWorkload.enabled"
    value = true
  }

  set {
    name  = "podIdentity.azureWorkload.clientId"
    value = var.keda_config.managed-identity
  }

  set {
    name  = "podIdentity.azureWorkload.tenantId"
    value = var.keda_config.tenant-id
  }
  set {
    name  = "operator.replicaCount"
    value = var.keda_config.replica_count
  }

  set {
    name  = "resources.operator.requests.memory"
    value = var.keda_config.requests_mem
  }
  set {
    name  = "resources.operator.requests.cpu"
    value = var.keda_config.requests_cpu
  }

  set {
    name  = "resources.operator.limits.memory"
    value = var.keda_config.limits_mem
  }

  set {
    name  = "resources.operator.limits.cpu"
    value = var.keda_config.limits_cpu
  }




  /*
  # Enabled Workload Identity on Job
  set {
    name  = "additionalLabels.azure\\.workload\\.identity\\/use"
    value = "true"
  }
*/
  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_namespace.keda_namespace
  ]
}
