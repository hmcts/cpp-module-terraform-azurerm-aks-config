locals {
  environment_type_abbreviation = var.environment_type == "live" ? "LVE" : "NLE"
}

# Create security groups
data "azuread_client_config" "current" {}

data "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

# Devops group is already admins on the cluster, This group is created if we have to additional admins.
resource "azuread_group" "aks_admin" {
  display_name     = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Admin"
  mail_enabled     = false
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
  members          = var.user_rbac.aks_cluster_admin_members_ids
}

resource "azuread_group" "aks_reader" {
  display_name     = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Reader"
  mail_enabled     = false
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
  members          = var.user_rbac.aks_reader_members_ids
}

resource "azuread_group" "aks_contributor" {
  display_name     = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Contributor"
  mail_enabled     = false
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
  members          = var.user_rbac.aks_contributor_members_ids
}

# Role assignments

resource "azurerm_role_assignment" "aks_admin" {
  scope                = data.azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.aks_admin.object_id
}

resource "azurerm_role_assignment" "aks_reader" {
  scope                = data.azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.aks_reader.object_id
}

resource "azurerm_role_assignment" "aks_contributor" {
  scope                = data.azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.aks_contributor.object_id
}

# store Groupids in the configmap
resource "kubectl_manifest" "store_aks_rbac_groupids" {
  yaml_body  = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${var.aks_rbac_configmap}
  namespace: ${var.aks_rbac_namespace}
data:
  clusterAdminGroup: ${azuread_group.aks_admin.object_id}
  readerGroupID: ${azuread_group.aks_reader.object_id}
  contributorGroupID: ${azuread_group.aks_contributor.object_id}
YAML
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

# Install User RBAC helm chart

resource "helm_release" "aks_rbac" {
  name       = lookup(var.charts.aks-rbac, "name", "aks-rbac")
  chart      = lookup(var.charts.aks-rbac, "name", "aks-rbac")
  version    = lookup(var.charts.aks-rbac, "version", "")
  values     = ["${file("${path.module}/chart-values/aks-rbac.yaml")}"]
  repository = "./install"
  namespace  = var.aks_rbac_namespace

  set {
    name  = "clusterRoles.cluster-admin.bindingSubjects.clusterAdminGroup.name"
    value = azuread_group.aks_admin.object_id
  }

  set {
    name  = "clusterRoles.namespace-readonly-role.bindingSubjects.readerGroupID.name"
    value = azuread_group.aks_reader.object_id
  }

  set {
    name  = "clusterRoles.namespace-readonly-role.bindingSubjects.contributorGroupID.name"
    value = azuread_group.aks_contributor.object_id
  }

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubectl_manifest.store_aks_rbac_groupids
  ]
}


data "kubernetes_service_account" "jenkins_admin_clusterrole_sa" {
  metadata {
    name      = var.jenkins_admin_sa
    namespace = var.aks_rbac_namespace
  }
  depends_on = [helm_release.aks_rbac]
}

data "kubernetes_secret" "jenkins_admin_clusterrole_secret" {
  metadata {
    name      = data.kubernetes_service_account.jenkins_admin_clusterrole_sa.default_secret_name
    namespace = var.aks_rbac_namespace
  }
}

data "kubernetes_service_account" "jenkins_deploy_clusterrole_sa" {
  metadata {
    name      = var.jenkins_deploy_sa
    namespace = var.aks_rbac_namespace
  }
  depends_on = [helm_release.aks_rbac]
}

data "kubernetes_secret" "jenkins_deploy_clusterrole_secret" {
  metadata {
    name      = data.kubernetes_service_account.jenkins_deploy_clusterrole_sa.default_secret_name
    namespace = var.aks_rbac_namespace
  }
}

resource "vault_generic_secret" "jenkins_admin_clusterrole_rbac" {
  path = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_admin_clusterrole_kubeconfig"

  data_json = jsonencode({
    value = templatefile("${path.module}/kubeconfig.tpl", {
      cluster_name    = var.aks_cluster_name
      server          = var.aks_server_endpoint
      service_account = var.jenkins_admin_sa
      namespace       = var.aks_rbac_namespace
      token           = data.kubernetes_secret.jenkins_admin_clusterrole_secret.data.token
      ca_data         = var.aks_ca_certificate
    })
  })
}


resource "vault_generic_secret" "jenkins_deploy_clusterrole_rbac" {
  path = "secret/terraform/${var.environment}/${var.aks_cluster_name}/jenkins_deploy_clusterrole_kubeconfig"

  data_json = jsonencode({
    value = templatefile("${path.module}/kubeconfig.tpl", {
      cluster_name    = var.aks_cluster_name
      server          = var.aks_server_endpoint
      service_account = var.jenkins_deploy_sa
      namespace       = var.aks_rbac_namespace
      token           = data.kubernetes_secret.jenkins_deploy_clusterrole_secret.data.token
      ca_data         = var.aks_ca_certificate
    })
  })
}
