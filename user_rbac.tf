locals {
  environment_type_abbreviation = var.environment_type == "live" ? "LVE" : "NLE"
  namespace_chart_values = yamldecode(file("${path.root}/chart-values/${var.environment_type}/${var.environment}/namespace.yaml"))
}

# Create security groups
data "azuread_client_config" "current" {}

data "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

# Devops group is already admins on the cluster, This group is created if we have to additional admins.
resource "azuread_group" "aks_admin" {
  display_name = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Admin"
  mail_enabled     = false
  security_enabled = true
  owners = [data.azuread_client_config.current.object_id]
  members = var.user_rbac.aks_cluster_admin_members_ids
}

resource "azuread_group" "aks_reader" {
  display_name = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Reader"
  mail_enabled     = false
  security_enabled = true
  owners = [data.azuread_client_config.current.object_id]
  members = var.user_rbac.aks_reader_members_ids
}

resource "azuread_group" "aks_contributor" {
  display_name = "GRP_${local.environment_type_abbreviation}_${var.aks_cluster_name}_Contributor"
  mail_enabled     = false
  security_enabled = true
  owners = [data.azuread_client_config.current.object_id]
  members = var.user_rbac.aks_contributor_members_ids
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

# Install User RBAC helm chart

resource "helm_release" "user_rbac_cluster_admin" {
  name             = lookup(var.charts.user-rbac, "name", "user-rbac")
  chart            = lookup(var.charts.user-rbac, "name", "user-rbac")
  version          = lookup(var.charts.user-rbac, "version", "")
  repository       = "./install"
  set {
    name  = "userRbac.clusterAdminGroupID"
    value = azuread_group.aks_admin.object_id
  }

  depends_on = [
    null_resource.download_charts,
    helm_release.namespace
  ]
}

resource "helm_release" "user_rbac_namespace" {
  for_each = { for namespace in local.namespace_chart_values.env : namespace.name => namespace }
  name             = lookup(var.charts.user-rbac, "name", "user-rbac")
  chart            = lookup(var.charts.user-rbac, "name", "user-rbac")
  version          = lookup(var.charts.user-rbac, "version", "")
  repository       = "./install"
  namespace        = each.value.name
  set {
    name  = "userRbac.contributorGroupID"
    value = azuread_group.aks_contributor.object_id
  }
  set {
    name  = "userRbac.readerGroupID"
    value = azuread_group.aks_reader.object_id
  }

  depends_on = [
    null_resource.download_charts,
    helm_release.namespace
  ]
}