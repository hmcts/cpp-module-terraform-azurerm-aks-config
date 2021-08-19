locals {
  jenkins_rbac_chart_values = yamldecode(file("${path.root}/chart-values/${var.environment}.yaml"))
}

# Need to improve auth to ACR. The helm provider v2 should be able to do it but cannot get it to working. Need to revisit.
# https://stackoverflow.com/questions/59565463/deploying-helm-charts-via-terraform-helm-provider-and-azure-devops-while-fetchin
resource "null_resource" "download_chart_jenkins_rbac" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      export HELM_EXPERIMENTAL_OCI=1
      helm registry login ${var.acr_name}.azurecr.io --username ${var.acr_user_name} --password ${var.acr_user_password}
      helm chart remove ${var.acr_name}.azurecr.io/${var.jenkins_rbac_chart_path}:${var.jenkins_rbac_chart_version}
      helm chart pull ${var.acr_name}.azurecr.io/${var.jenkins_rbac_chart_path}:${var.jenkins_rbac_chart_version}
      helm chart export ${var.acr_name}.azurecr.io/${var.jenkins_rbac_chart_path}:${var.jenkins_rbac_chart_version} --destination ./install
    EOT
  }
}

resource "helm_release" "jenkins_rbac" {
  name             = var.jenkins_rbac_chart_name
  chart            = var.jenkins_rbac_chart_name
  version          = var.jenkins_rbac_chart_version
  values           = ["${file("${path.root}/chart-values/${var.environment}.yaml")}"]
  repository       = "./install"
  namespace        = try(local.jenkins_rbac_chart_values.jenkinsRbac.adminSA.namespace)
  create_namespace = true
  depends_on       = [null_resource.download_chart_jenkins_rbac]
}

data "kubernetes_service_account" "jenkins_admin_sa" {
  metadata {
    name      = try(local.jenkins_rbac_chart_values.jenkinsRbac.adminSA.name)
    namespace = try(local.jenkins_rbac_chart_values.jenkinsRbac.adminSA.namespace)
  }
  depends_on = [helm_release.jenkins_rbac]
}

data "kubernetes_secret" "jenkins_admin_secret" {
  metadata {
    name      = data.kubernetes_service_account.jenkins_admin_sa.default_secret_name
    namespace = try(local.jenkins_rbac_chart_values.jenkinsRbac.adminSA.namespace)
  }
  binary_data = {
    "token" = ""
  }
}

data "kubernetes_service_account" "jenkins_deploy_sa" {
  for_each = { for namespace in local.jenkins_rbac_chart_values.jenkinsRbac.deploySA.namespaces : namespace.name => namespace }
  metadata {
    name      = try(local.jenkins_rbac_chart_values.jenkinsRbac.deploySA.name)
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
  binary_data = {
    "token" = ""
  }
  depends_on = [data.kubernetes_service_account.jenkins_deploy_sa]
}

data "template_file" "jenkins_rbac_admin_rendered_kubeconfig" {
  template = file("${path.module}/kubeconfig.tpl")
  vars = {
    cluster_name    = var.aks_cluster_name
    server          = var.aks_server_endpoint
    service_account = try(local.jenkins_rbac_chart_values.jenkinsRbac.adminSA.name)
    namespace       = "jenkins"
    token           = base64decode(data.kubernetes_secret.jenkins_admin_secret.binary_data.token)
    ca_data         = var.aks_ca_certificate
  }
}

data "template_file" "jenkins_rbac_deploy_rendered_kubeconfig" {
  for_each = data.kubernetes_secret.jenkins_deploy_secret
  template = file("${path.module}/kubeconfig.tpl")
  vars = {
    cluster_name    = var.aks_cluster_name
    server          = var.aks_server_endpoint
    service_account = try(local.jenkins_rbac_chart_values.jenkinsRbac.deploySA.name)
    namespace       = each.value.data.namespace
    token           = base64decode(each.value.binary_data.token)
    ca_data         = var.aks_ca_certificate
  }
}

resource "vault_generic_secret" "jenkins_admin_rbac" {
  path = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_admin_kubeconfig"

  data_json = jsonencode({
    value = data.template_file.jenkins_rbac_admin_rendered_kubeconfig.rendered
  })
}

resource "vault_generic_secret" "jenkins_deploy_rbac" {
  for_each = data.template_file.jenkins_rbac_deploy_rendered_kubeconfig
  path     = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_deploy_kubeconfig_${each.value.vars.namespace}"

  data_json = jsonencode({
    value = each.value.rendered
  })

  lifecycle {
    ignore_changes = [path]
  }
}