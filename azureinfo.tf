resource "kubernetes_namespace" "azure_info_namespace" {
  count = var.enable_azureinfo ? 1 : 0
  metadata {
    name = local.azure_info_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  lifecycle {
    ignore_changes = [metadata[0].labels["dynakube.internal.dynatrace.com/instance"]]
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubectl_manifest.dynatrace_cr_install
  ]
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
  for_each = { for role in var.resource_types : replace(replace(replace(role, " ", ""), "(", ""), ")", "") => role }

  name = each.value
}

locals {
  role_definitions = {
    for resource_type, role_definition in data.azurerm_role_definition.predefined_roles : resource_type => role_definition.id
  }
}

locals {
  azure_info_namespace         = "azure-info"
  azure_info_mi_resource_group = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/RG-MI-${var.aks_cluster_name}"
}

# Do not reference managed resources here. A planned change on any of them (for
# example per-run tag updates on azurerm_resource_group.aks) defers this read to
# apply time and makes store_azure_info show a diff in every plan.
data "kubectl_file_documents" "azure_info_manifests" {
  content = templatefile("${path.module}/manifests/common/azureinfo.yaml", {
    oidc_issuer_url   = data.azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
    subscription_id   = data.azurerm_client_config.current.subscription_id
    tenant_id         = data.azurerm_client_config.current.tenant_id
    role_definitions  = join("\n  ", [for role_name, role_id in local.role_definitions : "${role_name}: ${role_id}"])
    namespace         = local.azure_info_namespace
    mi_resource_group = local.azure_info_mi_resource_group
    cluster_name      = var.aks_cluster_name
  })
}

resource "kubectl_manifest" "store_azure_info" {
  count     = length(split("\n---\n", file("${path.module}/manifests/common/azureinfo.yaml")))
  yaml_body = element(data.kubectl_file_documents.azure_info_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.azure_info_namespace,
    azurerm_resource_group.aks,
  ]
}
