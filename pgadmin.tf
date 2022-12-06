resource "kubernetes_namespace" "pgadmin_namespace" {
  count = 1
  metadata {
    name = "pgadmin"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
    }
  }
}

resource "helm_release" "pgadmin" {
  count      = var.enable_pgadmin ? 1 : 0
  name       = lookup(var.charts.pgadmin, "name", "pgadmin")
  chart      = lookup(var.charts.pgadmin, "name", "pgadmin")
  version    = lookup(var.charts.pgadmin, "version", "")
  repository = "./install"
  namespace  = "pgadmin"

  set {
    name  = "pgadmindefaults.admin_user"
    value = var.pgadmin_admin_user
  }

  set {
    name  = "pgadmindefaults.admin_password"
    value = var.pgadmin_admin_password
  }

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.pgadmin_namespace
  ]
}
