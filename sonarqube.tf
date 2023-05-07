resource "kubernetes_namespace" "sonarqube_namespace" {
  count = var.sonarqube_config.enable ? 1 : 0
  metadata {
    name = "sonarqube"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "helm_release" "sonarqube_install" {
  count      = var.sonarqube_config.enable ? 1 : 0
  name       = lookup(var.charts.sonarqube, "name", "sonarqube")
  chart      = lookup(var.charts.sonarqube, "name", "sonarqube")
  version    = lookup(var.charts.sonarqube, "version", "")
  repository = "./install"
  namespace  = "sonarqube"

  set {
    name  = "image.repo"
    value = "${var.acr_name}.azurecr.io/hmcts/sonarqube/sonarqube"
  }
  set {
    name  = "postgresql.enable"
    value = false
  }
  set {
    name  = "jdbcOverwrite.enable"
    value = true
  }
  set {
    name  = "jdbcOverwrite.jdbcUrl"
    value = var.sonarqube_config.jdbcUrl
  }
  set {
    name  = "jdbcOverwrite.jdbcUsername"
    value = data.vault_generic_secret.sonaqube_cred.0.data["dbUser"]
  }
  set {
    name  = "jdbcOverwrite.jdbcPassword"
    value = data.vault_generic_secret.sonaqube_cred.0.data["dbPwd"]
  }
  set {
    name  = "gateway.host"
    value = var.sonarqube_config.sonarqubeUrl
  }
  set {
    name  = "sonarProperties"
    value = <<EOT
sonar.forceAuthentication: true
sonar.auth.saml.loginUrl: https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/saml2
sonar.auth.saml.providerId: https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/
sonar.auth.saml.applicationId: https://${var.sonarqube_config.sonarqubeUrl}/saml
sonar.auth.saml.enabled: true
sonar.core.serverBaseURL: https://${var.sonarqube_config.sonarqubeUrl}
sonar.auth.saml.signature.enabled: false
sonar.auth.saml.user.login: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name
sonar.auth.saml.user.name: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name
sonar.auth.saml.group.name: http://schemas.microsoft.com/ws/2008/06/identity/claims/groups
sonar.auth.saml.certificate.secured: ${data.vault_generic_secret.sonaqube_cred.0.data["spCert"]}
EOT
  }

  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_namespace.sonarqube_namespace
  ]
}
