# Install configmap with omsagent configuration
resource "kubectl_manifest" "omsagent_configmap_manifest" {
  yaml_body = templatefile("${path.module}/manifests/omsagent/container-azm-ms-agentconfig.yaml", {
    log_collection_settings_stdout_enabled = var.omsagent.log_collection_settings_stdout_enabled
    log_collection_settings_stderr_enabled = var.omsagent.log_collection_settings_stderr_enabled
  })
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}
