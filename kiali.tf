resource "kubernetes_namespace" "kiali_namespace" {
  metadata {
    name = "kiali-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
}

data "vault_generic_secret" "kiali_auth" {
  path = "secret/mgmt/k8s_monitor_password"
}

resource "kubernetes_secret" "kiali_pass" {

  metadata {
    name      = "kiali"
    namespace = "istio-system"
  }

  data = {
    oidc-secret = data.vault_generic_secret.kiali_auth.data["value"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.kiali_namespace
  ]
}

resource "helm_release" "kiali_operator_install" {
  name       = lookup(var.charts.kiali-operator, "name", "kiali-operator")
  chart      = lookup(var.charts.kiali-operator, "name", "kiali-operator")
  version    = lookup(var.charts.kiali-operator, "version", "")
  repository = "./install"
  namespace  = "kiali-operator"

  set {
    name  = "cr.namespace"
    value = "istio-system"
  }
  set {
    name  = "image.repo"
    value = "${var.acr_name}.azurecr.io/quay.io/kiali/kiali-operator"
  }
  set {
    name  = "cr.spec.deployment.image_name"
    value = "${var.acr_name}.azurecr.io/quay.io/kiali/kiali"
  }
  set {
    name  = "cr.spec.auth.openid.client_id"
    value = lookup(var.monitor_config, "client_id")
  }
  set {
    name  = "cr.spec.auth.openid.issuer_uri"
    value = lookup(var.monitor_config, "issuer_uri")
  }
  set {
    name  = "cr.spec.auth.openid.additional_request_params.resource"
    value = lookup(var.monitor_config, "shared_resource_id")
  }

  wait              = true
  timeout           = 300

  depends_on = [null_resource.download_charts,kubernetes_secret.kiali_pass]
}