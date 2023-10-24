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


data "azurerm_role_definition" "predefined_roles" {
  for_each = { for role in var.resource_types : role => role }

  name = each.value
}

locals {
  role_definitions = {
    for resource_type, role_definition in data.azurerm_role_definition.predefined_roles : resource_type => role_definition.id
  }
}


resource "kubectl_manifest" "store_azure_info" {
  count = var.enable_azureinfo ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/common/azureinfo.yaml", {
    oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
    subscription_id  = data.azurerm_client_config.current.subscription_id
    tenant_id        = data.azurerm_client_config.current.tenant_id
    role_definitions = join("\n", [for role_name, role_id in local.role_definitions : "${role_name}: ${role_id}"])
    namespace        = kubernetes_namespace.azure_info_namespace[0].metadata.0.name
  })
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}
