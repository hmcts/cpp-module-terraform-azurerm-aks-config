resource "helm_release" "namespace" {
  name       = lookup(var.charts.namespace, "name", "namespace")
  chart      = lookup(var.charts.namespace, "name", "namespace")
  version    = lookup(var.charts.namespace, "version", "")
  values     = ["${file("${path.root}/chart-values/${var.environment_type}/${var.environment}/namespace.yaml")}"]
  repository = "./install"
  depends_on = [
    null_resource.download_charts,
    time_sleep.wait_for_istio_crds
  ]
}

resource "kubectl_manifest" "delete_adhoc_ns" {
  yaml_body = file("${path.module}/manifests/common/delete_adhoc_ns.yaml")
}