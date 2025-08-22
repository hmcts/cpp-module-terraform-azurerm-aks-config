resource "kubernetes_namespace" "ado-agents_namespace" {
  count = var.ado-agents_config.enable ? 1 : 0
  metadata {
    name = var.ado-agents_config.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "app.kubernetes.io/name"       = "ccm-namespace"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubernetes_service_account" "ado_agent" {
  count = var.ado-agents_config.enable ? 1 : 0
  metadata {
    name      = var.ado-agents_config.sa_name
    namespace = var.ado-agents_config.namespace

    annotations = {
      "azure.workload.identity/client-id" = "${var.ado-agents_config.managed-identity}"
    }
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.ado-agents_namespace,
    helm_release.keda_install
  ]

}

# This is to limit routes to only ado-agent and istio-system NS.
resource "kubectl_manifest" "default_egress_sidecar" {
  count     = (var.ado-agents_config.enable) ? 1 : 0
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
 name: default-egress
 namespace: ${var.ado-agents_config.namespace}
spec:
 egress:
 - hosts:
   - "./*"
   - "istio-system/*"
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.ado-agents_namespace
  ]
}

#
# var.ado-agents_config.enable true AND var.ado-agents_config.scaledjob set to True so Install ScaledJob not Job
# https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md
#  https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md#example-for-scaledobject

resource "kubectl_manifest" "azdevops_scaledjob_triggerauth" {
  count     = (var.ado-agents_config.enable) ? 1 : 0
  yaml_body = <<YAML
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: pipeline-trigger-auth
  namespace: ${var.ado-agents_config.namespace}
spec:
  podIdentity:
    provider: azure-workload
    identityId: "${var.ado-agents_config.managed-identity}"
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.ado-agents_namespace,
    helm_release.keda_install
  ]
  force_new = true
}

#
# var.ado-agents_config.enable true AND var.ado-agents_config.scaledjob set to True so Install ScaledJob not Job
# https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md
#  https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md#example-for-scaledobject

resource "kubectl_manifest" "azdevops_agent" {
  for_each = (var.ado-agents_config.enable) ? { for agent in var.ado-agents_config.agents : agent.agent_name => agent } : {}
  yaml_body = templatefile("${path.module}/manifests/ado-agents/ado_agents.yaml.tpl", {
    environment                = var.environment
    aks_cluster_set            = var.aks_cluster_set
    aks_cluster_number         = var.aks_cluster_number
    namespace                  = var.ado-agents_config.namespace
    agent_name                 = each.value.agent_name
    poolname                   = var.ado-agents_config.poolname
    identifier                 = each.value.identifier
    enable_istio_proxy         = each.value.enable_istio_proxy
    sa_name                    = var.ado-agents_config.sa_name
    acr_name                   = var.acr_name
    image_name                 = each.value.image_name
    image_tag                  = each.value.image_tag
    azpurl                     = var.ado-agents_config.azpurl
    tenant_id                  = var.ado-agents_config.tenant-id
    subscription_id            = var.ado-agents_config.subscription-id
    aks_cluster_name           = var.aks_cluster_name
    limits_cpu                 = each.value.limits_cpu
    limits_mem                 = each.value.limits_mem
    requests_cpu               = each.value.requests_cpu
    requests_mem               = each.value.requests_mem
    pollinginterval            = each.value.pollinginterval
    successfuljobshistorylimit = each.value.successfuljobshistorylimit
    failedjobshistorylimit     = each.value.failedjobshistorylimit
    scaled_min_job             = each.value.scaled_min_job
    scaled_max_job             = each.value.scaled_max_job
    init_containers            = jsonencode(each.value.init_container_config)
    run_as_user                = each.value.run_as_user
  })

  lifecycle {
    ignore_changes = [field_manager]
  }

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.ado-agents_namespace,
    helm_release.keda_install,
    kubernetes_service_account.ado_agent,
  ]

  force_new = true
}
