resource "helm_release" "jenkins_rbac" {
  name             = lookup(var.charts.jenkins-rbac, "name", "jenkins-rbac")
  chart            = lookup(var.charts.jenkins-rbac, "name", "jenkins-rbac")
  version          = lookup(var.charts.jenkins-rbac, "version", "")
  values           = ["${file("${path.root}/chart-values/${var.environment}.yaml")}"]
  repository       = "./install"
  namespace        = try(local.chart_values.jenkinsRbac.adminSA.namespace)
  create_namespace = true
  depends_on       = [
    null_resource.download_charts,
    helm_release.namespace
  ]
}

data "kubernetes_service_account" "jenkins_admin_sa" {
  metadata {
    name      = try(local.chart_values.jenkinsRbac.adminSA.name)
    namespace = try(local.chart_values.jenkinsRbac.adminSA.namespace)
  }
  depends_on = [helm_release.jenkins_rbac]
}

data "kubernetes_secret" "jenkins_admin_secret" {
  metadata {
    name      = data.kubernetes_service_account.jenkins_admin_sa.default_secret_name
    namespace = try(local.chart_values.jenkinsRbac.adminSA.namespace)
  }
}

data "kubernetes_service_account" "jenkins_deploy_sa" {
  for_each = { for namespace in local.chart_values.jenkinsRbac.deploySA.namespaces : namespace.name => namespace }
  metadata {
    name      = try(local.chart_values.jenkinsRbac.deploySA.name)
    namespace = each.value.name
  }
  depends_on = [helm_release.jenkins_rbac]
}

data "kubernetes_secret" "jenkins_deploy_secret" {
  for_each = data.kubernetes_service_account.jenkins_deploy_sa
  metadata {
    name      = each.value.default_secret_name
    namespace = try(each.key)
  }
  depends_on = [data.kubernetes_service_account.jenkins_deploy_sa]
}

resource "vault_generic_secret" "jenkins_admin_rbac" {
  path = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_admin_kubeconfig"

  data_json = jsonencode({
    value = templatefile("${path.module}/kubeconfig.tpl", {
      cluster_name    = var.aks_cluster_name
      server          = var.aks_server_endpoint
      service_account = try(local.chart_values.jenkinsRbac.adminSA.name)
      namespace       = try(local.chart_values.jenkinsRbac.adminSA.namespace)
      token           = data.kubernetes_secret.jenkins_admin_secret.data.token
      ca_data         = var.aks_ca_certificate
    })
  })
}

resource "vault_generic_secret" "jenkins_deploy_rbac" {
  for_each = { for namespace in local.chart_values.jenkinsRbac.deploySA.namespaces : namespace.name => namespace }
  path     = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_deploy_kubeconfig_${each.value.name}"

  data_json = jsonencode({
    value = templatefile("${path.module}/kubeconfig.tpl", {
      cluster_name    = var.aks_cluster_name
      server          = var.aks_server_endpoint
      service_account = try(local.chart_values.jenkinsRbac.deploySA.name)
      namespace       = each.value.name
      token           = data.kubernetes_secret.jenkins_deploy_secret[each.value.name].data.token
      ca_data         = var.aks_ca_certificate
    })
  })
}