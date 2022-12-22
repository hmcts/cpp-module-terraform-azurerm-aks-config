data "azurerm_client_config" "current" {}

resource "kubectl_manifest" "delete_validation_ns" {
  count      = var.delete_validation_ns ? 1 : 0
  yaml_body  = file("${path.module}/manifests/common/delete_validation_ns.yaml")
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "null_resource" "wait_for_k8s_api_to_be_available" {
  provisioner "local-exec" {
    command = "echo k8s-api-dns-count: ${length(var.wait_for_k8s_api_to_be_available)} acr-pe-ip: ${var.wait_for_acr_pe_to_be_available}"
  }
}

resource "time_sleep" "wait_for_aks_api_dns_propagation" {
  depends_on = [
    null_resource.wait_for_k8s_api_to_be_available
  ]
  create_duration = "60s"
}
