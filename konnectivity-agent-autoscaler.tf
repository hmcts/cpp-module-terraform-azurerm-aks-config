resource "kubectl_manifest" "konnectivity_agent_autoscaler_configmap" {
  count = var.konnectivity_agent_autoscaler.enabled ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/konnectivity-agent-autoscaler/configmap.yaml", {
    ladder = jsonencode({
      coresToReplicas = var.konnectivity_agent_autoscaler.cores_to_replicas
      nodesToReplicas = var.konnectivity_agent_autoscaler.nodes_to_replicas
    })
  })

  lifecycle {
    ignore_changes = [field_manager]
  }

  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}
