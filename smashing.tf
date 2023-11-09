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
    value = "SCHEDULER_HMCTS_DASHBOARD_REFRESH_INTERVAL"
  }

  set {
    name  = "env[2].value"
    value = var.smashing_scheduler_hmcts_dashboards_interval
  }

  set {
    name  = "env[3].name"
    value = "SCHEDULER_NAMESPACE_INFO_REFRESH_INTERVAL"
  }

  set {
    name  = "env[3].value"
    value = var.smashing_scheduler_namespace_info_interval
  }

  set {
    name  = "env[4].name"
    value = "SCHEDULER_SUSPEND_STACKS_REFRESH_INTERVAL"
  }

  set {
    name  = "env[4].value"
    value = var.smashing_scheduler_suspend_stacks_refresh_interval
  }

  set {
    name  = "env[5].name"
    value = "IDLE_TIME_MINUTES"
  }

  set {
    name  = "env[5].value"
    value = var.smashing_idle_time_minutes
    type  = "string"
  }

  set {
    name  = "env[6].name"
    value = "PROMETHEUS_URL"
  }

  set {
    name  = "env[6].value"
    value = "http://kube-prometheus-stack-prometheus.prometheus\\.svc\\.cluster\\.local:9090"
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
