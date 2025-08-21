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
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
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
  set {
    name  = "audit.resources.requests.memory"
    value = "512Mi"
  }
  set {
    name  = "audit.resources.limits.memory"
    value = "1Gi"
  }


  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.gatekeeper_namespace
  ]
}

data "kubectl_path_documents" "gatekeeper_manager_manifests" {
    pattern = "${path.module}/manifests/gatekeeper/constraint.yaml"
}

resource "kubectl_manifest" "install_gatekeeper_constraint_manifests" {
  count     = var.gatekeeper_config.enable ? length(split("\n---\n", file("${path.module}/manifests/gatekeeper/constraint.yaml"))) : 0
  yaml_body = element(data.kubectl_path_documents.gatekeeper_manager_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    helm_release.gatekeeper_install
  ]
}

resource "kubectl_manifest" "install_gatekeeper_whitelistedimages_manifests" {
  count     = var.gatekeeper_config.enable ? 1 : 0
  yaml_body = file("${path.module}/manifests/gatekeeper/whitelistedimages.yaml")
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    helm_release.gatekeeper_install
  ]
}
