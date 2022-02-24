resource "helm_release" "istio_operator_install" {
  name       = lookup(var.charts.istio-operator, "name", "istio-operator")
  chart      = lookup(var.charts.istio-operator, "name", "istio-operator")
  version    = lookup(var.charts.istio-operator, "version", "")
  repository = "./install"

  set {
    name  = "operatorNamespace"
    value = "istio-operator"
  }

  set {
    name  = "hub"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/istio"
  }

  set {
    name  = "tag"
    value = var.charts.istio-operator.version
  }

  depends_on = [null_resource.download_charts]
}

resource "kubernetes_namespace" "istio_namespace" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable" = "enabled"
    }
  }
}

# Apply IstioOperator manifest to the operator 
resource "kubectl_manifest" "istio_operator_manifest" {
  yaml_body = templatefile("${path.module}/manifests/istio/istio_operator.yaml", {
    istio_node_selector                        = var.istio_node_selector_label
    istio_ingress_load_balancer_resource_group = var.istio_ingress_load_balancer_resource_group
    systempool_taint_key                       = var.systempool_taint_key
    docker_registry                            = "${var.acr_name}.azurecr.io/registry.hub.docker.com/istio"
    docker_tag                                 = var.charts.istio-operator.version
    hpa_min_replicas                           = var.istio_components_hpa_spec.min_replicas
    hpa_max_replicas                           = var.istio_components_hpa_spec.max_replicas
  })

  depends_on = [
    helm_release.istio_operator_install,
    kubernetes_namespace.istio_namespace
  ]
}

resource "time_sleep" "wait_for_istio_crds" {
  depends_on = [kubectl_manifest.istio_operator_manifest]
  triggers = {
    istio_operator_id = kubectl_manifest.istio_operator_manifest.uid
  }

  create_duration = "30s"
}

# Istio gateway menifest 

data "kubectl_file_documents" "istio_gateway_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_gateway.yaml", {
    ingress-gateway-secret = var.istio_gateway_cert_secret_name
    ingressdomain          = var.ingressdomain
    aks_cluster_name       = var.aks_cluster_name
  })
}

resource "kubectl_manifest" "istio_gateway_manifest" {
  count     = length(data.kubectl_file_documents.istio_gateway_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_gateway_manifests.documents, count.index)
  depends_on = [
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    time_sleep.wait_for_istio_crds
  ]
}

# PeerAuthentication menifest - Enable mtls 

resource "kubectl_manifest" "enable_mtls" {
  yaml_body = file("${path.module}/manifests/istio/istio_peerauthentication.yaml")
}