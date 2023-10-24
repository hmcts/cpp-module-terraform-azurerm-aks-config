resource "kubernetes_namespace" "azure_info_namespace" {
  count = var.enable_azureinfo ? 1 : 0
  metadata {
    name = "azure-info"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "azurerm_resource_group" "aks" {
  name     = "RG-MI-${var.aks_cluster_name}"
  location = var.aks_cluster_location
  tags     = var.tags
  lifecycle {
    ignore_changes = [tags["created_by"], tags["created_time"]]
  }
}

data "azurerm_role_definition" "predefined_roles" {
  for_each = { for role in var.resource_types : replace(role, " ", "_") => role }

  name = each.value
}

locals {
  role_definitions = {
    for resource_type, role_definition in data.azurerm_role_definition.predefined_roles : resource_type => role_definition.id
  }
}

data "kubectl_file_documents" "azure_info_manifests" {
  content = templatefile("${path.module}/manifests/common/azureinfo.yaml", {
    oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
    subscription_id  = data.azurerm_client_config.current.subscription_id
    tenant_id        = data.azurerm_client_config.current.tenant_id
    role_definitions = join("\n    ", [for role_name, role_id in local.role_definitions : "${role_name}: ${role_id}"])
    namespace        = kubernetes_namespace.azure_info_namespace[0].metadata.0.name
    mi_resource_group = azurerm_resource_group.aks.name
  })
}

resource "kubectl_manifest" "store_azure_info" {
  count      = length(split("\n---\n", file("${path.module}/manifests/common/azureinfo.yaml")))
  yaml_body  = element(data.kubectl_file_documents.azure_info_manifests.documents, count.index)
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation, kubernetes_namespace.azure_info_namespace, data.kubectl_file_documents.azure_info_manifests]
}

#resource "kubectl_manifest" "store_azure_info" {
#  yaml_body = templatefile("${path.module}/manifests/common/azureinfo.yaml", {
#        oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
#        subscription_id  = data.azurerm_client_config.current.subscription_id
#        tenant_id        = data.azurerm_client_config.current.tenant_id
#        role_definitions = join("\n    ", [for role_name, role_id in local.role_definitions : "${role_name}: ${role_id}"])
#        namespace        = kubernetes_namespace.azure_info_namespace[0].metadata.0.name
#        mi_resource_group = azurerm_resource_group.aks.name
#  })
#  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
#}
