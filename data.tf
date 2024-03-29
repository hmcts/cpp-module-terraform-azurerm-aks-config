resource "time_sleep" "wait_for_loadbalancer_apps" {
  depends_on = [
    helm_release.istio_ingress_apps_install,
    kubectl_manifest.install_istio_ingress_gateway_apps_manifests
  ]
  create_duration = "120s"
}

resource "time_sleep" "wait_for_loadbalancer_mgmt" {
  depends_on = [
    helm_release.istio_ingress_mgmt_install,
    kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests
  ]
  create_duration = "120s"
}

resource "time_sleep" "wait_for_loadbalancer_web" {
  depends_on = [
    helm_release.istio_ingress_web_install,
    kubectl_manifest.install_istio_ingress_gateway_web_manifests
  ]
  create_duration = "120s"
}

data "kubernetes_service" "mgmt_gateway_svc" {
  metadata {
    name      = "istio-ingressgateway-mgmt"
    namespace = "istio-ingress-mgmt"
  }
  depends_on = [
    time_sleep.wait_for_loadbalancer_mgmt,
    kubernetes_namespace.istio_ingress_mgmt_namespace
  ]
}

data "kubernetes_service" "app_gateway_svc" {
  metadata {
    name      = "istio-ingressgateway-apps"
    namespace = "istio-ingress"
  }
  depends_on = [
    time_sleep.wait_for_loadbalancer_apps,
    kubernetes_namespace.istio_ingress_namespace
  ]
}

data "kubernetes_service" "web_gateway_svc" {
  metadata {
    name      = "istio-ingressgateway-web"
    namespace = "istio-ingress-web"
  }
  depends_on = [
    time_sleep.wait_for_loadbalancer_web,
    kubernetes_namespace.istio_ingress_web_namespace
  ]
}

data "azurerm_resources" "fl_postgres_list" {
  type                = "Microsoft.DBforPostgreSQL/flexibleservers"
  resource_group_name = var.pgadmin_postgres_rg
}

data "azurerm_postgresql_flexible_server" "fl_postgres" {
  count               = length(data.azurerm_resources.fl_postgres_list.resources)
  name                = data.azurerm_resources.fl_postgres_list.resources[count.index].name
  resource_group_name = var.pgadmin_postgres_rg
}

data "azurerm_resources" "s_postgres_list" {
  type                = "Microsoft.DBforPostgreSQL/servers"
  resource_group_name = var.pgadmin_postgres_rg
}

data "azurerm_postgresql_server" "s_postgres" {
  count               = length(data.azurerm_resources.s_postgres_list.resources)
  name                = data.azurerm_resources.s_postgres_list.resources[count.index].name
  resource_group_name = var.pgadmin_postgres_rg
}

data "vault_generic_secret" "sonaqube_cred" {
  count = var.sonarqube_config.enable ? 1 : 0
  path  = var.sonarqube_config.sonarVaultPath
}

data "vault_generic_secret" "ca_cert" {
  path = var.ca_bundle_path
}
