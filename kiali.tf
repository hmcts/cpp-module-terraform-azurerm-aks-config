resource "kubernetes_namespace" "kiali_namespace" {
  count = var.enable_moniotring ? 1 : 0
  metadata {
    name = "kiali-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
}

data "vault_generic_secret" "kiali_auth" {
  path = "secret/mgmt/spn_k8s_monitor"
}

resource "kubernetes_secret" "kiali_pass" {
  count = var.enable_moniotring ? 1 : 0
  metadata {
    name      = "kiali"
    namespace = "istio-system"
  }

  data = {
    oidc-secret = data.vault_generic_secret.kiali_auth.data["client_secret"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.kiali_namespace,
    kubernetes_namespace.istio_system_namespace
  ]
}

resource "helm_release" "kiali_operator_install" {
  count = var.enable_moniotring ? 1 : 0
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

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_secret.kiali_pass
  ]
}

resource "kubectl_manifest" "install_kiali_virtualservice_manifests" {
  count = var.enable_moniotring ? 1 : 0
  yaml_body          = templatefile("${path.module}/manifests/kiali/virtualservice.yaml", {
    namespace         = "istio-system"
    gateway           = "istio-ingress/istio-ingressgateway-mgmt"
    kiali_hostname    = "${var.kiali_hostname_prefix}${split("*", var.istio_ingress_mgmt_domain)[1]}"
    kiali_destination = "kiali"
  })
  override_namespace = "istio-system"
  depends_on = [
    helm_release.kiali_operator_install,
    kubectl_manifest.install_istio_ingress_gateway_manifests
  ]
}