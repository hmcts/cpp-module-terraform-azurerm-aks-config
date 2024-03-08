data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "kubectl_manifest" "delete_validation_ns" {
  count     = var.delete_validation_ns ? 1 : 0
  yaml_body = file("${path.module}/manifests/common/delete_validation_ns.yaml")
  lifecycle {
    ignore_changes = [field_manager]
  }
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

data "kubectl_file_documents" "network_policy_manifests" {
  content = templatefile("${path.module}/manifests/common/networkpolicy.yaml", {
    namespace         = ["istio-ingress-mgmt", "istio-system", "kube-system"]
    system_namespaces = var.system_namespaces
  })
}


resource "kubectl_manifest" "install_mgmt_networkpolicies" {
  for_each  = { for i, value in data.kubectl_file_documents.network_policy_manifests.documents : i => value }
  yaml_body = each.value
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [kubernetes_namespace.prometheus_namespace, kubernetes_namespace.sonarqube_namespace, kubernetes_namespace.kiali_namespace, kubernetes_namespace.pgadmin_namespace]
}
