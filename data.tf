resource "time_sleep" "wait_for_loadbalancer" {
  depends_on = [
    helm_release.istio_ingress_mgmt_install,
    helm_release.istio_ingress_apps_install,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
  create_duration = "120s"
}

data "kubernetes_service" "mgmt_gateway_svc" {
  metadata {
    name      = "istio-ingressgateway-mgmt"
    namespace = "istio-ingress"
  }
  depends_on = [
    time_sleep.wait_for_loadbalancer
  ]
}

data "kubernetes_service" "app_gateway_svc" {
  metadata {
    name      = "istio-ingressgateway-apps"
    namespace = "istio-ingress"
  }
  depends_on = [
    time_sleep.wait_for_loadbalancer
  ]
}

data "azurerm_private_link_service" "ingress_apps" {
  name                = "PLS-${upper(var.aks_cluster_name)}-INGRESS-APPS"
  resource_group_name = var.istio_ingress_load_balancer_resource_group
  depends_on = [
    helm_release.istio_ingress_mgmt_install,
    helm_release.istio_ingress_apps_install,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
}

data "azurerm_private_link_service" "ingress_mgmt" {
  name                = "PLS-${upper(var.aks_cluster_name)}-INGRESS-MGMT"
  resource_group_name = var.istio_ingress_load_balancer_resource_group
  depends_on = [
    helm_release.istio_ingress_mgmt_install,
    helm_release.istio_ingress_apps_install,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
}
