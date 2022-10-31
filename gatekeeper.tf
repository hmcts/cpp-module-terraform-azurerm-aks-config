resource "kubernetes_namespace" "gatekeeper_namespace" {
  count = var.gatekeeper_config.enable ? 1 : 0
  metadata {
    name = "gatekeeper-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "disabled"
      "istio-injection"              = "disabled"
    }
  }
}

resource "helm_release" "gatekeeper_install" {
  count      = var.gatekeeper_config.enable ? 1 : 0
  name       = lookup(var.charts.gatekeeper, "name", "gatekeeper")
  chart      = lookup(var.charts.gatekeeper, "name", "gatekeeper")
  version    = lookup(var.charts.gatekeeper, "version", "")
  repository = "./install"
  namespace  = "gatekeeper-system"

  set {
    name  = "replicas"
    value = var.gatekeeper_config.replicas
  }
  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/openpolicyagent/gatekeeper"
  }
  set {
    name  = "image.crdRepository"
    value = "${var.acr_name}.azurecr.io/docker.io/openpolicyagent/gatekeeper-crds"
  }
  set {
    name  = "postUpgrade.labelNamespace.image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/openpolicyagent/gatekeeper-crds"
  }
  set {
    name  = "postInstall.labelNamespace.image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/openpolicyagent/gatekeeper-crds"
  }
  set {
    name  = "postInstall.probeWebhook.image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/curlimages/curl"
  }
  set {
    name  = "preUninstall.deleteWebhookConfigurations.image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/openpolicyagent/gatekeeper-crds"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.gatekeeper_namespace
  ]
}

resource "kubectl_manifest" "install_gatekeeper_constraint_manifests" {
  count     = var.gatekeeper_config.enable ? 1 : 0
  yaml_body = file("${path.module}/manifests/gatekeeper/constraint.yaml")

  depends_on = [
    helm_release.gatekeeper_install
  ]
}

resource "kubectl_manifest" "install_gatekeeper_whitelistedimages_manifests" {
  count     = var.gatekeeper_config.enable ? 1 : 0
  yaml_body = file("${path.module}/manifests/gatekeeper/whitelistedimages.yaml")

  depends_on = [
    helm_release.gatekeeper_install
  ]
}
