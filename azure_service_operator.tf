
resource "kubernetes_namespace" "azure_service_operator_namespace" {
  count = var.enable_azure_service_operator ? 1 : 0
  metadata {
    name = "azureserviceoperator-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "azure_service_operator" {
  count      = var.enable_azure_service_operator ? 1 : 0
  name       = lookup(var.charts.azure_service_operator, "name", "azure-service-operator")
  chart      = lookup(var.charts.azure_service_operator, "name", "azure-service-operator")
  version    = lookup(var.charts.azure_service_operator, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.azure_service_operator_namespace[0].metadata.0.name

  set {
    name  = "image.repository"
    value = "mcr.microsoft.com/k8s/azureserviceoperator:${var.azure_service_operator_tag}"
  }

  set {
    name  = "image.kubeRBACProxy"
    value = "${var.acr_name}/gcr.io/kubebuilder/kube-rbac-proxy:${var.kube_rbac_proxy_tag}"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.azure_service_operator_namespace,
    kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests,
    kubectl_manifest.install_gatekeeper_whitelistedimages_manifests
  ]
}
