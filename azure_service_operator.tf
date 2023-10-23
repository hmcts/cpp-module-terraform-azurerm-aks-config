
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
  name       = lookup(var.charts.azure-service-operator, "name", "azure-service-operator")
  chart      = lookup(var.charts.azure-service-operator, "name", "azure-service-operator")
  version    = lookup(var.charts.azure-service-operator, "version", "")
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

  set {
    name  = "azureSubscriptionID"
    value = data.azurerm_client_config.current.subscription_id
  }

  set {
    name  = "azureTenantID"
    value = data.azurerm_client_config.current.tenant_id
  }

  set {
    name  = "azureClientID"
    value = data.azurerm_client_config.current.client_id
  }

  set_sensitive {
    name  = "azureClientSecret"
    value = data.vault_generic_secret.azure_app_secret.data.value
  }

  set {
    name  = "crdPattern"
    value = var.azure_service_operator_crdpattern
  }

  set {
    name  = "resources.limits.cpu"
    value = var.aso_resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.aso_resources.limits.memory
  }

  set {
    name  = "resources.requests.cpu"
    value = var.aso_resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.aso_resources.requests.memory
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
