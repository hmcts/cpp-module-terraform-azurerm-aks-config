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
  type       = "Opaque"
  depends_on = [kubernetes_namespace.dynatrace_namespace]
}

resource "kubectl_manifest" "dynatrace_cr_install" {
  count = var.enable_dynatrace ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/dynatrace/dynatrace.com_dynakubes.yaml", {
    apiUrl               = var.dynatrace_api
    networkZone          = var.dynatrace_networkzone
    systempool_taint_key = var.systempool_taint_key
    hostGroup            = "${upper(var.environment)}_CRIME_CP_AKS"
    oneagent_image       = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/dynatrace-oneagent:${var.dynatrace_oneagent_image_tag}"
  })
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [helm_release.dynatrace_operator, kubernetes_secret.dynatrace_token]
}

# Comprehensive ClusterRole for manual cluster registration with all Dynatrace permissions
# Includes all permissions needed for Kubernetes monitoring and Prometheus exporters
resource "kubernetes_cluster_role" "dynatrace_monitoring_additional" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name = "dynatrace-kubernetes-monitoring-additional"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  # Core Kubernetes resources
  rule {
    api_groups = [""]
    resources  = ["nodes", "pods", "namespaces", "services", "endpoints", "events"]
    verbs      = ["get", "list", "watch"]
  }
  # Prometheus exporters require configmaps, secrets, and pods/proxy access
  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }
  # Pod proxy access for Prometheus metrics scraping
  rule {
    api_groups = [""]
    resources  = ["pods/proxy", "nodes/proxy", "nodes/metrics"]
    verbs      = ["get", "list", "watch"]
  }
  # Dynatrace CRDs - required for cluster validation
  rule {
    api_groups = ["dynatrace.com"]
    resources  = ["dynakubes", "edgeconnects"]
    verbs      = ["get", "list", "watch"]
  }
  # Apps and workload resources
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
  # Batch resources
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch"]
  }
}

# Bind additional permissions to dynatrace-activegate ServiceAccount
resource "kubernetes_cluster_role_binding" "dynatrace_monitoring_additional" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name = "dynatrace-kubernetes-monitoring-additional"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.dynatrace_monitoring_additional[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "dynatrace-activegate"
    namespace = "dynatrace"
  }
  depends_on = [
    kubernetes_cluster_role.dynatrace_monitoring_additional,
    helm_release.dynatrace_operator
  ]
}

# Token secret for manual cluster registration (K8s 1.24+)
# Reuses the dynatrace-activegate ServiceAccount created by Helm chart
# This SA is already bound to dynatrace-kubernetes-monitoring ClusterRole
resource "kubernetes_secret_v1" "dynatrace_kubernetes_monitoring_token" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name      = "dynatrace-kubernetes-monitoring"
    namespace = "dynatrace"
    annotations = {
      "kubernetes.io/service-account.name" = "dynatrace-activegate"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [
    helm_release.dynatrace_operator,
    kubernetes_cluster_role_binding.dynatrace_monitoring_additional
  ]
}
