resource "kubernetes_namespace" "dynatrace_namespace" {
  count = var.enable_dynatrace ? 1 : 0
  metadata {
    name = "dynatrace"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable" = "enabled"
    }
  }
}

data "kubectl_file_documents" "dynatrace_manifests" {
  content = file("${path.module}/manifests/dynatrace/dynatrace_operator.yaml")
}

data "kubectl_file_documents" "dynatrace_hpa_manifests" {
  content = templatefile("${path.module}/manifests/dynatrace/dynatrace_hpa.yaml", {
    hpa_min_replicas        = var.dynatrace_components_hpa_spec.min_replicas
    hpa_max_replicas        = var.dynatrace_components_hpa_spec.max_replicas
    hpa_avg_cpu_utilization = var.dynatrace_components_hpa_spec.avg_cpu_utilization
    hpa_avg_mem_utilization = var.dynatrace_components_hpa_spec.avg_mem_utilization
  })
}

# added new manifest for operator deployment
resource "kubectl_manifest" "dynatrace_operator_deployment" {
  count = var.enable_dynatrace ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/dynatrace/dynatrace_operator_deploy.yaml", {
    systempool_taint_key            = var.systempool_taint_key
    affinity_exp_key                = var.node_affinity_exp_key
    affinity_exp_value              = var.node_affinity_exp_value
    docker_image_dynatrace_operator = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/dynatrace-operator"
    docker_tag_dynatrace_operator   = "v0.2.1"
  })

  depends_on = [
    kubernetes_namespace.dynatrace_namespace
  ]
}

resource "kubectl_manifest" "dynatrace_operator_manifest" {
  count     = var.enable_dynatrace ? length(data.kubectl_file_documents.dynatrace_manifests.documents) : 0
  yaml_body = element(data.kubectl_file_documents.dynatrace_manifests.documents, count.index)
  depends_on = [
    kubernetes_namespace.dynatrace_namespace,
    data.kubectl_file_documents.dynatrace_manifests
  ]
}

resource "kubectl_manifest" "dynatrace_hpa_manifest" {
  count     = var.enable_dynatrace ? length(data.kubectl_file_documents.dynatrace_hpa_manifests.documents) :0
  yaml_body = element(data.kubectl_file_documents.dynatrace_hpa_manifests.documents, count.index)
  depends_on = [
    kubectl_manifest.dynatrace_operator_manifest
  ]
}

resource "kubectl_manifest" "dynatrace_secret_manifest" {
  count = var.enable_dynatrace ? 1 : 0
  sensitive_fields = ["api_token", "paas_token"]
  yaml_body = templatefile("${path.module}/manifests/dynatrace/dynatrace_secret.yaml", {
    api_token  = var.dynatrace_api_token
    paas_token = var.dynatrace_paas_token
  })
  depends_on = [
    kubectl_manifest.dynatrace_operator_manifest
  ]
}

resource "kubectl_manifest" "dynatrace_cr_manifest" {
  count = var.enable_dynatrace ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/dynatrace/dynatrace_cr.yaml", {
    dynatrace_api         = var.dynatrace_api
    network_zone          = "${var.dynatrace_networkzone}"
    cluster_name          = "${var.environment}-cpp"
    docker_image_oneagent = "${var.acr_name}.azurecr.io/registry.hub.docker.com/dynatrace/oneagent"
  })
  depends_on = [
    kubectl_manifest.dynatrace_secret_manifest
  ]
}
