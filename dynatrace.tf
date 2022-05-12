resource "kubernetes_namespace" "dynatrace_namespace" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name = "dynatrace"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
}

resource "kubectl_manifest" "dynatrace_operator_crd_install" {
  count     = var.enable_dynatrace ? 1 : 0
  yaml_body = file("${path.module}/manifests/dynatrace/dynatrace.com_dynakubes.yaml")
}

resource "helm_release" "dynatrace_operator" {
  count      = var.enable_dynatrace ? 1 : 0
  name       = lookup(var.charts.dynatrace-operator, "name", "dynatrace-operator")
  chart      = lookup(var.charts.dynatrace-operator, "name", "dynatrace-operator")
  version    = lookup(var.charts.dynatrace-operator, "version", "")
  repository = "./install"
  namespace  = "dynatrace"

  set {
    name  = "operator.tolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "operator.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "operator.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "operator.nodeSelector.${var.dynatrace_operator_node_selector.key}"
    value = var.dynatrace_operator_node_selector.value
  }

  set {
    name  = "operator.image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/dynatrace-operator:v0.5.1"
  }

  set {
    name  = "apiUrl"
    value = var.dynatrace_api
  }

  set {
    name  = "apiToken"
    value = var.dynatrace_api_token
  }

  set {
    name  = "paasToken"
    value = var.dynatrace_paas_token
  }

  set {
    name  = "dataIngestToken"
    value = ""
  }

  set {
    name  = "networkZone"
    value = var.dynatrace_networkzone
  }

  set {
    name  = "classicFullStack.enabled"
    value = true
  }

  set {
    name  = "classicFullStack.tolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "classicFullStack.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "classicFullStack.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "classicFullStack.image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/oneagent"
  }

  set {
    name  = "classicFullStack.version"
    value = "latest"
  }

  set {
    name  = "classicFullStack.env[0].name"
    value = "ONEAGENT_INSTALLER_DOWNLOAD_TOKEN"
  }

  set {
    name  = "classicFullStack.env[0].valueFrom.secretKeyRef.name"
    value = "dynakube"
  }

  set {
    name  = "classicFullStack.env[0].valueFrom.secretKeyRef.key"
    value = "paasToken"
  }

  set {
    name  = "classicFullStack.env[0].valueFrom.secretKeyRef.key"
    value = "paasToken"
  }

  set {
    name  = "classicFullStack.env[1].name"
    value = "ONEAGENT_INSTALLER_SCRIPT_URL"
  }

  set {
    name  = "classicFullStack.env[1].value"
    value = "${var.dynatrace_api}/v1/deployment/installer/agent/unix/default/latest?arch=x86"
  }

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.dynatrace_namespace,
    kubectl_manifest.dynatrace_operator_crd_install
  ]
}