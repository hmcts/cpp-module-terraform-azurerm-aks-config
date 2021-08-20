resource "helm_release" "istio_operator_install" {
  name             = lookup(var.charts.istio-operator, "name", "istio-operator")
  chart            = lookup(var.charts.istio-operator, "name", "istio-operator")
  version          = lookup(var.charts.istio-operator, "version", "")
  repository       = "./install"

  set {
    name  = "operatorNamespace"
    value = "istio-operator"
  }

  depends_on       = [null_resource.download_charts]
}

resource "kubernetes_namespace" "istio_namespace" {
  metadata {
    name = "istio-system"
  }
}

# Apply IstioOperator manifest to the operator 
resource "kubectl_manifest" "istio_operator_manifest" {
  yaml_body = templatefile("${path.module}/manifests/istio.yaml", {
    istio_node_selector                        = var.istio_node_selector_label
    istio_ingress_load_balancer_resource_group = var.istio_ingress_load_balancer_resource_group
    systempool_taint_key                       = var.systempool_taint_key
  })

  depends_on = [
    helm_release.istio_operator_install,
    kubernetes_namespace.istio_namespace
  ]
}