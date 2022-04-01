output "jenkins_rbac_deploy" {
  value = [
    for k, v in vault_generic_secret.jenkins_deploy_rbac : tomap({"namespace" = k, "vault_path" = v.path})
  ]
}

output "jenkins_rbac_admin" {
  value = vault_generic_secret.jenkins_admin_rbac.path
}

output "ingress_apps_domain_name" {
  value = "${split("*", var.istio_ingress_apps_domain)[1]}"
}