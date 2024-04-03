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

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.dynatrace_namespace,
    time_sleep.wait_for_aks_api_dns_propagation
  ]
}

resource "kubernetes_secret" "dynatrace_token" {
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
    apiUrl                = var.dynatrace_api
    classicFullStackImage = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/oneagent"
    networkZone           = var.dynatrace_networkzone
    systempool_taint_key  = var.systempool_taint_key
    hostGroup             = "${upper(var.environment)}_CRIME_CP_AKS"
    version               = var.dynatrace_oneagent_version
  })
  depends_on = [helm_release.dynatrace_operator, kubernetes_secret.dynatrace_token]
}

resource "kubernetes_secret_v1" "dynatrace_clusterrole_secret" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name      = "dynatrace-kubernetes-monitoring"
    namespace = "dynatrace"
    annotations = {
      "kubernetes.io/service-account.name" = "dynatrace-kubernetes-monitoring"
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [helm_release.dynatrace_operator]
}
