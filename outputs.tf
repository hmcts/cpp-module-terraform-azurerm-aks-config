output "jenkins_rbac_deploy" {
  value = vault_generic_secret.jenkins_deploy_clusterrole_rbac.path
}

output "jenkins_rbac_admin" {
  value = vault_generic_secret.jenkins_admin_clusterrole_rbac.path
}

output "ingress_apps_domain_name" {
  value = split("*", var.istio_ingress_apps_domains[0])[1]
}

output "ingress_lb_private_ip_address_apps" {
  value = data.kubernetes_service.app_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "ingress_lb_private_ip_address_mgmt" {
  value = data.kubernetes_service.mgmt_gateway_svc.status.0.load_balancer.0.ingress.0.ip
}

output "private_link_service_ingress_apps_id" {
  value = data.azurerm_private_link_service.ingress_apps.id
}

output "private_link_service_ingress_mgmt_id" {
  value = data.azurerm_private_link_service.ingress_mgmt.id
}
