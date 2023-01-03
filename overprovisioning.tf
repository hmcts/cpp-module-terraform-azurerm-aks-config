resource "kubernetes_namespace" "overprovisioning_namespace" {
  count = var.overprovisioning.enable ? 1 : 0
  metadata {
    name = "overprovisioning"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "disabled"
      "istio-injection"              = "disabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "overprovisioning_install" {
  count      = var.overprovisioning.enable ? 1 : 0
  name       = lookup(var.charts.overprovisioning, "name", "overprovisioning")
  chart      = lookup(var.charts.overprovisioning, "name", "overprovisioning")
  version    = lookup(var.charts.overprovisioning, "version", "")
  repository = "./install"
  namespace  = "overprovisioning"

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/k8s.gcr.io/pause"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "replicaCount"
    value = var.overprovisioning.replica_count
  }

  set {
    name  = "priorityClass.value"
    value = "-1"
  }

  set {
    name  = "resources.limits.cpu"
    value = var.overprovisioning.resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.overprovisioning.resources.limits.memory
  }

  set {
    name  = "resources.requests.cpu"
    value = var.overprovisioning.resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.overprovisioning.resources.requests.memory
  }

  wait    = true
  timeout = 500

  depends_on = [
    kubernetes_namespace.overprovisioning_namespace,
    null_resource.download_charts
  ]
}
