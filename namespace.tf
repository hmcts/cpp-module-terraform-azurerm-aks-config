resource "helm_release" "namespace" {
  name             = lookup(var.charts.namespace, "name", "namespace")
  chart            = lookup(var.charts.namespace, "name", "namespace")
  version          = lookup(var.charts.namespace, "version", "")
  values           = ["${file("${path.root}/chart-values/${var.environment}.yaml")}"]
  repository       = "./install"
  depends_on       = [null_resource.download_charts]
}
