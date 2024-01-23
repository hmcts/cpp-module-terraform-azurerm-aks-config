resource "kubernetes_namespace" "ado-agents_namespace" {
  count = var.ado-agents_config.enable ? 1 : 0
  metadata {
    name = var.ado-agents_config.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "disabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}


resource "kubernetes_secret" "azdevops" {
  count = var.ado-agents_config.enable ? 1 : 0
  metadata {
    name      = var.ado-agents_config.secretname
    namespace = var.ado-agents_config.namespace
  }

  data = {
    "${var.ado-agents_config.secretkey}" = var.ado-pat
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.ado-agents_namespace
  ]
}


#
# var.ado-agents_config.enable true AND var.ado-agents_config.scaledjob set to True so Install ScaledJob not Job
# https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md
#  https://github.com/kedacore/keda-docs/blob/main/content/docs/2.14/scalers/azure-pipelines.md#example-for-scaledobject

resource "kubectl_manifest" "azdevops_agent" {
  for_each  = (var.ado-agents_config.enable) ? { for agent in var.ado-agents_config.agents : agent.agent_name => agent } : {}
  yaml_body = <<YAML
---
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: ${var.environment}-${var.aks_cluster_set}-${var.aks_cluster_number}-${each.value.agent_name}
  namespace: ${var.ado-agents_config.namespace}
spec:
  triggers:
    - type: azure-pipelines
      metadata:
        poolName: "${var.ado-agents_config.poolname}"
        organizationURLFromEnv: "AZP_URL"
        personalAccessTokenFromEnv: "AZP_TOKEN"
        demands: "identifier -equals ${each.value.identifier}"
  jobTargetRef:
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: azdevops-agent
            image: "${var.acr_name}.azurecr.io/hmcts/${each.value.image_name}:${each.value.image_tag}"
            imagePullPolicy: Always
            env:
              - name: AZP_URL
                value: "${var.ado-agents_config.azpurl}"
              - name: AZP_POOL
                value: "${var.ado-agents_config.poolname}"
              - name: AZP_TOKEN
                valueFrom:
                  secretKeyRef:
                    key: AZP_TOKEN
                    name: "${var.ado-agents_config.secretname}"
              - name: identifier
                value: "${each.value.identifier}"
        resources:
          limits:
            cpu: "${each.value.limits_cpu}"
            memory: "${each.value.limits_mem}"
          requests:
            cpu: "${each.value.requests_cpu}"
            memory: "${each.value.requests_mem}"
  pollingInterval: 10
  successfulJobsHistoryLimit: 0
  failedJobsHistoryLimit: 0
  minReplicaCount: ${each.value.scaled_min_job}
  maxReplicaCount: ${each.value.scaled_max_job}
  rollout:
    strategy: gradual
YAML

  depends_on = [
    time_sleep.wait_for_aks_api_dns_propagation,
    kubernetes_namespace.ado-agents_namespace,
    kubernetes_secret.azdevops,
    helm_release.keda_install,
  ]
  force_new = true
}
