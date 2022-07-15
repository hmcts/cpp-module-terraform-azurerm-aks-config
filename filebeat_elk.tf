resource "kubernetes_namespace" "filebeat_namespace" {
  count      = var.enable_elk ? 1 : 0
  metadata {
    name = var.filebeat_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# get the redis password from the vault
# rediscache_password: "{​​​​​​{​​​​​​ lookup('vault','secret/' ~ env ~ '/int/elk_redis_cache_password').value }​​​​​​}​​​​​​"

data "vault_generic_secret" "redis_auth" {
  path = "secret/${var.environment}/int/elk_redis_cache_password"
}

resource "kubernetes_secret" "redis_pass" {
  count      = var.enable_elk ? 1 : 0
  metadata {
    name      = "redis-creds"
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
  count      = var.enable_elk ? 1 : 0
  name    = lookup(var.charts.filebeat-mgm, "name", "filebeat-mgm")
  chart   = "filebeat"
  version = lookup(var.charts.filebeat-mgm, "version", "")
  values = [
    "${file("${path.root}/chart-values/common/filebeat-mgmt.yaml")}",
    "${file("${path.root}/chart-values/${var.environment_type}/${var.environment}/filebeat-mgmt.yaml")}"
  ]
  set {
    name  = "image"
    value = "${var.acr_name}.azurecr.io/docker.elastic.co/beats/filebeat"
  }

  set {
    name  = "imageTag"
    value = "8.0.0-SNAPSHOT"
  }

  repository = "./install"
  namespace  = var.filebeat_namespace

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.filebeat_namespace
  ]
}

resource "helm_release" "filebeat_application" {
  count      = var.enable_elk ? 1 : 0
  name    = lookup(var.charts.filebeat-app, "name", "filebeat-app")
  chart   = "filebeat"
  version = lookup(var.charts.filebeat-app, "version", "")
  values = [
    "${file("${path.root}/chart-values/common/filebeat-app.yaml")}",
    "${file("${path.root}/chart-values/${var.environment_type}/${var.environment}/filebeat-app.yaml")}"
  ]
  set {
    name  = "image"
    value = "${var.acr_name}.azurecr.io/docker.elastic.co/beats/filebeat"
  }

  set {
    name  = "imageTag"
    value = "8.0.0-SNAPSHOT"
  }
  
  repository = "./install"
  namespace  = var.filebeat_namespace

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.filebeat_namespace
  ]
}