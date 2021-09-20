resource "kubernetes_namespace" "filebeat_namespace" {
  metadata {
    name = var.filebeat_namespace
  }
}

# get the redis password from the vault
# rediscache_password: "{​​​​​​{​​​​​​ lookup('vault','secret/' ~ env ~ '/int/elk_redis_cache_password').value }​​​​​​}​​​​​​"

data "vault_generic_secret" "redis_auth" {
  path = "secret/${var.environment}/int/elk_redis_cache_password"
}

resource "kubernetes_secret" "redis_pass" {
  
  metadata {
    name = "redis-creds"
    namespace = var.filebeat_namespace
  }

  data = {
    redis_password = data.vault_generic_secret.redis_auth.data["value"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.filebeat_namespace
  ]
}

resource "helm_release" "filebeat_management" {
  name             = lookup(var.charts.filebeat-mgm, "name", "filebeat-mgm")
  chart            = "filebeat"
  version          = lookup(var.charts.filebeat-mgm, "version", "")
  values           = ["${file("${path.root}/chart-values/logging/${var.environment}-mgm.yaml")}"]
  repository       = "./install"
  namespace        = var.filebeat_namespace

  depends_on       = [
    null_resource.download_charts,
    kubernetes_namespace.filebeat_namespace
  ]
}

resource "helm_release" "filebeat_application" {
  name             = lookup(var.charts.filebeat-app, "name", "filebeat-app")
  chart            = "filebeat"
  version          = lookup(var.charts.filebeat-app, "version", "")
  values           = ["${file("${path.root}/chart-values/logging/${var.environment}-app.yaml")}"]
  repository       = "./install"
  namespace        = var.filebeat_namespace

  depends_on       = [
    null_resource.download_charts,
    kubernetes_namespace.filebeat_namespace
  ]
}