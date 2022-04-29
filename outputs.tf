output "jenkins_rbac_deploy" {
  value = vault_generic_secret.jenkins_deploy_clusterrole_rbac.path
}

output "jenkins_rbac_admin" {
  value = vault_generic_secret.jenkins_admin_clusterrole_rbac.path
}

output "ingress_apps_domain_name" {
  value = "${split("*", var.istio_ingress_apps_domain)[1]}"
}
