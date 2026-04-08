resource "kubernetes_namespace" "sonarqube_namespace" {
  count = var.sonarqube_config.enable ? 1 : 0
  metadata {
    name = "sonarqube"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "disabled"
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



resource "helm_release" "sonarqube_install" {
  count      = var.sonarqube_config.enable ? 1 : 0
  name       = lookup(var.charts.sonarqube, "name", "sonarqube")
  chart      = lookup(var.charts.sonarqube, "name", "sonarqube")
  version    = lookup(var.charts.sonarqube, "version", "")
  repository = "./install"
  namespace  = "sonarqube"

  set {
    name  = "image.repository"
    value = "${var.acr_name}.azurecr.io/docker.io/library/sonarqube"
  }
  set {
    name  = "community.enabled"
    value = true
  }
  set {
    name  = "community.buildNumber"
    value = var.sonarqube_config.community_build_number
  }
  set {
    name  = "postgresql.enabled"
    value = false
  }
  set {
    name  = "jdbcOverwrite.enabled"
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
    name  = "gateway.hosts"
    value = var.sonarqube_config.hosts
  }
  set {
    name  = "gateway.name"
    value = "istio-ingress-mgmt/istio-ingressgateway-mgmt"
  }
  set {
    name  = "initContainers.image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/library/busybox:1.35.0"
  }
  set {
    name  = "initFs.image"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/library/busybox:1.35.0"
  }
  set {
    name  = "initSysctl.enabled"
    value = true
  }
  set {
    name  = "securityContext.fsGroup"
    value = 1000
  }
  set {
    name  = "gateway.serviceDestinationPort"
    value = 9000
  }
  set {
    name  = "gateway.timeout"
    value = "120s"
  }
  set {
    name  = "persistence.enabled"
    value = true
  }
  set {
    name  = "nodeSelector.agentpool"
    value = "sysagentpool"
  }
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  values = [templatefile("${path.module}/manifests/common/sonarProps.yaml", {
    tenant_id    = data.azurerm_client_config.current.tenant_id
    sonarqubeUrl = var.sonarqube_config.sonarqubeUrl
    spCert       = data.vault_generic_secret.sonaqube_cred.0.data["spCert"]
  })]

  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    null_resource.download_charts,
    kubernetes_namespace.sonarqube_namespace,
    kubectl_manifest.install_gatekeeper_whitelistedimages_manifests
  ]
}
