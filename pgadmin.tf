resource "kubernetes_namespace" "pgadmin_namespace" {
  count = 1
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
  namespace  = "pgadmin"

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dpage/pgadmin4"
  }

  set {
    name  = "image.tag"
    value = "6.14"
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
    name  = "gateway.host"
    value = var.pgadmin_hostnames
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.pgadmin_namespace
  ]
}

resource "kubectl_manifest" "install_pgadmin_virtualservice_manifests" {
  yaml_body = templatefile("${path.module}/manifests/pgadmin/virtualservice.yaml", {
    namespace           = "istio-system"
    gateway             = "istio-ingress/istio-ingressgateway-mgmt"
    pgadmin_hostnames   = var.pgadmin_hostnames
    pgadmin_destination = "pgadmin"
  })
  override_namespace = "pgadmin"
  depends_on = [
    helm_release.pgadmin,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
}
