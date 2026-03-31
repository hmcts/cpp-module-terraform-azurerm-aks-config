resource "kubernetes_namespace" "dynatrace_namespace" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name = "dynatrace"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "dynatrace_operator" {
  count      = var.enable_dynatrace ? 1 : 0
  name       = lookup(var.charts.dynatrace-operator, "name", "dynatrace-operator")
  chart      = lookup(var.charts.dynatrace-operator, "name", "dynatrace-operator")
  version    = lookup(var.charts.dynatrace-operator, "version", "")
  repository = "./install"
  namespace  = "dynatrace"

  set {
    name  = "operator.tolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "operator.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "operator.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "operator.nodeSelector.${var.dynatrace_operator_node_selector.key}"
    value = var.dynatrace_operator_node_selector.value
  }

  set {
    name  = "image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/dynatrace-operator:${var.dynatrace_operator_image_tag}"
  }

  set {
    name  = "csidriver.enabled"
    value = true
  }

  set {
    name  = "csidriver.tolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "csidriver.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "csidriver.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "csidriver.tolerations[1].key"
    value = "PrometheusOnly"
  }

  set {
    name  = "csidriver.tolerations[1].operator"
    value = "Exists"
  }

  set {
    name  = "csidriver.tolerations[1].effect"
    value = "NoSchedule"
  }

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.dynatrace_namespace,
    time_sleep.wait_for_aks_api_dns_propagation
  ]
}

resource "kubernetes_secret" "dynatrace_token" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name      = "dynakube"
    namespace = "dynatrace"
  }
  data = {
    apiToken = var.dynatrace_api_token
  }
  type = "Opaque"
}

resource "kubectl_manifest" "dynatrace_cr_install" {
  count = var.enable_dynatrace ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/dynatrace/dynatrace.com_dynakubes.yaml", {
    apiUrl               = var.dynatrace_api
    networkZone          = var.dynatrace_networkzone
    systempool_taint_key = var.systempool_taint_key
    hostGroup            = "${upper(var.environment)}_CRIME_CP_AKS"
  })
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [helm_release.dynatrace_operator, kubernetes_secret.dynatrace_token]
}

# Removed: kubernetes_secret_v1.dynatrace_clusterrole_secret
# This service account token secret is no longer needed with Dynatrace Operator v1.8.1
# The Dynatrace operator handles authentication internally with cloudNativeFullStack mode
