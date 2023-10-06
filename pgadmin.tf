locals {
  flexible_server = [
    for fqdn in data.azurerm_postgresql_flexible_server.fl_postgres.*.fqdn :
    { group_name = "flexible_server", fqdn = fqdn }
  ]
  postgres_server = [
    for fqdn in data.azurerm_postgresql_server.s_postgres.*.fqdn :
    { group_name = "postgres_server", fqdn = fqdn }
  ]
  server_groups              = concat(local.flexible_server, local.postgres_server)
  server_list_content_base64 = base64encode(templatefile("${path.module}/server_list.tftpl", { server_groups = local.server_groups }))
}


resource "kubernetes_namespace" "pgadmin_namespace" {
  count = var.enable_pgadmin ? 1 : 0
  metadata {
    name = "pgadmin"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "pgadmin" {
  count      = var.enable_pgadmin ? 1 : 0
  name       = lookup(var.charts.pgadmin, "name", "pgadmin")
  chart      = lookup(var.charts.pgadmin, "name", "pgadmin")
  version    = lookup(var.charts.pgadmin, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.pgadmin_namespace[0].metadata.0.name

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dpage/pgadmin4"
  }

  set {
    name  = "image.tag"
    value = var.pgadmin_tag
  }

  set {
    name  = "pgadmindefaults.admin_user"
    value = var.pgadmin_admin_user
  }

  set {
    name  = "pgadmindefaults.admin_password"
    value = var.pgadmin_admin_password
  }
  set {
    name = "pgadmin_port"
    value = var.pgadmin_port
  }
  set {
    name = "externaldb_host"
    value = var.externaldb_host
  }
  set {
    name = "externaldb_port"
    value = var.externaldb_port
  }
  set {
    name = "externaldb_name"
    value = var.externaldb_name
  }
  set {
    name = "externaldb_admin_user"
    value = var.externaldb_admin_user
  }
  set {
    name = "externaldb_admin_password"
    value = var.externaldb_admin_password
  }
  set {
    name = "pgadmin_shared_storage_path"
    value = var.pgadmin_shared_storage_path
  }
  set{
    name = "pgadmin_restrict_storage_access"
    value = var.pgadmin_restrict_storage_access
  }

  set {
    name  = "pgadminoauth2.tenantId"
    value = var.pgadmin_oauth2_tenantid
  }
  set {
    name  = "pgadminoauth2.clientId"
    value = var.pgadmin_oauth2_clientid
  }
  set {
    name  = "pgadminoauth2.clientSecret"
    value = var.pgadmin_oauth2_clientsecret
  }
  set {
    name  = "gateway.name"
    value = "istio-ingress-mgmt/istio-ingressgateway-mgmt"
  }
  set {
    name  = "gateway.host"
    value = var.pgadmin_hostnames
  }
  set {
    name  = "server_list_base64"
    value = local.server_list_content_base64
  }
  set {
    name  = "initContainers.image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/library/busybox"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.pgadmin_namespace,
    kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests,
    kubectl_manifest.install_gatekeeper_whitelistedimages_manifests
  ]
}
