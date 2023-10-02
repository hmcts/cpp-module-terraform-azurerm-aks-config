resource "kubernetes_namespace" "smashing_namespace" {
  count = var.enable_smashing ? 1 : 0
  metadata {
    name = "smashing"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "smashing_install" {
  count      = var.enable_smashing ? 1 : 0
  name       = lookup(var.charts.smashing, "name", "smashing")
  chart      = lookup(var.charts.smashing, "name", "smashing")
  version    = lookup(var.charts.smashing, "version", "")
  repository = "./install"
  namespace  = "smashing"

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/hmcts/smashing"
  }

  set {
    name  = "image.tag"
    value = var.smashing_image_tag
  }

  set {
    name  = "env[0].name"
    value = "aks_cluster"
  }

  set {
    name  = "env[0].value"
    value = var.aks_cluster_name
  }

  set {
    name  = "env[1].name"
    value = "domain"
  }

  set {
    name  = "env[1].value"
    value = local.addns.domain
  }

  set {
    name  = "env[2].name"
    value = "SCHEDULER_RENDER_DASHBOARDS_INTERVAL"
  }

  set {
    name  = "env[2].value"
    value = var.smashing_scheduler_render_dashboards_interval
  }

  set {
    name  = "env[3].name"
    value = "SCHEDULER_ENVIRONMENT_INFO_INTERVAL"
  }

  set {
    name  = "env[3].value"
    value = var.smashing_scheduler_environment_info_interval
  }

  set {
    name  = "gateway.host"
    value = var.smashing_gateway_host_name
  }

  wait    = true
  timeout = 500

  depends_on = [
    kubernetes_namespace.overprovisioning_namespace,
    null_resource.download_charts
  ]
}
