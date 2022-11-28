data "azurerm_lb" "ingress_lb" {
  name                = var.istio_ingress_load_balancer_name
  resource_group_name = var.istio_ingress_load_balancer_resource_group
  depends_on = [
    helm_release.istio_ingress_mgmt_install,
    helm_release.istio_ingress_apps_install,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
}
