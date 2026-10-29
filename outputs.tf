output "jenkins_rbac_deploy" {
  description = "Vault path containing the Jenkins deployment RBAC credentials"
  value       = vault_generic_secret.jenkins_deploy_clusterrole_rbac.path
}

output "jenkins_rbac_admin" {
  description = "Vault path containing the Jenkins administrator RBAC credentials"
  value       = vault_generic_secret.jenkins_admin_clusterrole_rbac.path
}

output "akv_jenkins_rbac_deploy" {
  description = "Key Vault secret ID for Jenkins deployment RBAC credentials, or an empty string when disabled"
  value       = var.enable_azure_keyvault ? azurerm_key_vault_secret.jenkins_deploy_clusterrole_rbac[0].id : ""
}

output "akv_jenkins_rbac_admin" {
  description = "Key Vault secret ID for Jenkins administrator RBAC credentials, or an empty string when disabled"
  value       = var.enable_azure_keyvault ? azurerm_key_vault_secret.jenkins_admin_clusterrole_rbac[0].id : ""
}

output "ingress_apps_domain_name" {
  description = "Domain suffix from the first apps ingress wildcard, including the leading dot"
  value       = split("*", var.istio_ingress_apps_domains[0])[1]
}

output "ingress_lb_private_ip_address_apps" {
  description = "Private frontend IP address of the apps Istio ingress Service"
  value       = data.kubernetes_service.app_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "ingress_lb_private_ip_address_mgmt" {
  description = "Private frontend IP address of the management Istio ingress Service"
  value       = data.kubernetes_service.mgmt_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "ingress_lb_private_ip_address_web" {
  description = "Private frontend IP address of the web Istio ingress Service"
  value       = data.kubernetes_service.web_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "ingress_lb_private_ip_address_oauth" {
  description = "Private frontend IP address of the OAuth Istio ingress Service"
  value       = data.kubernetes_service.oauth_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "private_link_service_ingress_apps_id" {
  description = "Resource ID of the apps ingress Private Link Service"
  value       = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.istio_ingress_load_balancer_resource_group}/providers/Microsoft.Network/privateLinkServices/${local.privatelink_service_apps_ingress_name}"
  depends_on  = [null_resource.ingress_apps]
}

output "private_link_service_ingress_mgmt_id" {
  description = "Resource ID of the management ingress Private Link Service"
  value       = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.istio_ingress_load_balancer_resource_group}/providers/Microsoft.Network/privateLinkServices/${local.privatelink_service_mgmt_ingress_name}"
  depends_on  = [null_resource.ingress_mgmt]
}

output "private_link_service_ingress_web_id" {
  description = "Resource ID of the web ingress Private Link Service"
  value       = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.istio_ingress_load_balancer_resource_group}/providers/Microsoft.Network/privateLinkServices/${local.privatelink_service_web_ingress_name}"
  depends_on  = [null_resource.ingress_web]
}

output "private_link_service_ingress_oauth_id" {
  description = "Resource ID of the OAuth ingress Private Link Service"
  value       = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.istio_ingress_load_balancer_resource_group}/providers/Microsoft.Network/privateLinkServices/${local.privatelink_service_oauth_ingress_name}"
  depends_on  = [null_resource.ingress_oauth]
}

output "kubernetes_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster"
  value       = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
}
