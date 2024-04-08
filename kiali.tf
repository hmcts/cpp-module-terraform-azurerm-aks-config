resource "kubernetes_namespace" "kiali_namespace" {
  metadata {
    name = "kiali-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

data "vault_generic_secret" "kiali_auth" {
  path = "secret/mgmt/spn_k8s_monitor"
}

resource "kubernetes_secret" "kiali_pass" {

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
    name  = "replicaCount"
    value = var.kiali_operator_replicas
  }
  set {
    name  = "resources.requests.memory"
    value = var.kiali_operator_memory_request
  }
  set {
    name  = "resources.requests.cpu"
    value = var.kiali_operator_cpu_request
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
    name  = "cr.spec.deployment.replicas"
    value = var.kiali_cr_spec.replica_count
  }
  set {
    name  = "cr.spec.deployment.resources.requests.cpu"
    value = var.kiali_cr_spec.resources.requests.cpu
  }
  set {
    name  = "cr.spec.deployment.resources.requests.memory"
    value = var.kiali_cr_spec.resources.requests.memory
  }
  set {
    name  = "cr.spec.deployment.resources.limits.cpu"
    value = var.kiali_cr_spec.resources.limits.cpu
  }
  set {
    name  = "cr.spec.deployment.resources.limits.memory"
    value = var.kiali_cr_spec.resources.limits.memory
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
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_secret.kiali_pass,
    kubectl_manifest.install_gatekeeper_whitelistedimages_manifests
  ]
}

resource "kubectl_manifest" "install_kiali_virtualservice_manifests" {
  yaml_body = templatefile("${path.module}/manifests/kiali/virtualservice.yaml", {
    namespace         = "istio-system"
    gateway           = "istio-ingress-mgmt/istio-ingressgateway-mgmt"
    kiali_hostnames   = var.kiali_hostnames
    kiali_destination = "kiali"
  })
  override_namespace = "istio-system"
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    helm_release.kiali_operator_install,
    kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests,
  ]
}
