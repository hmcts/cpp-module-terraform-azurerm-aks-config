resource "kubernetes_namespace" "dynatrace_namespace" {
  metadata {
    name = "dynatrace"
  }
}

data "kubectl_file_documents" "dynatrace_manifests" {
  content = file("${path.module}/manifests/dynatrace_operator.yaml")
}

# added new manifest for operator deployment
resource "kubectl_manifest" "dynatrace_operator_deployment" {
  yaml_body = templatefile("${path.module}/manifests/dynatrace_operator_deploy.yaml", {
    systempool_taint_key = var.systempool_taint_key
    affinity_exp_key     = var.node_affinity_exp_key
    affinity_exp_value   = var.node_affinity_exp_value
  })

  depends_on = [
    kubernetes_namespace.dynatrace_namespace
  ]
}

resource "kubectl_manifest" "dynatrace_operator_manifest" {
  count     = length(data.kubectl_file_documents.dynatrace_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.dynatrace_manifests.documents, count.index)
  depends_on = [
    kubernetes_namespace.dynatrace_namespace,
    data.kubectl_file_documents.dynatrace_manifests
  ]
}

resource "kubectl_manifest" "dynatrace_secret_manifest" {
  sensitive_fields = ["api_token", "paas_token"]
  yaml_body = templatefile("${path.module}/manifests/dynatrace_secret.yaml", {
    api_token  = var.dynatrace_api_token
    paas_token = var.dynatrace_paas_token
  })
  depends_on = [
    kubectl_manifest.dynatrace_operator_manifest
  ]
}

resource "kubectl_manifest" "dynatrace_cr_manifest" {
  yaml_body = templatefile("${path.module}/manifests/dynatrace_cr.yaml", {
    dynatrace_api = var.dynatrace_api
    cluster_name  = "${var.environment}-cpp"
  })
  depends_on = [
    kubectl_manifest.dynatrace_secret_manifest
  ]
}
