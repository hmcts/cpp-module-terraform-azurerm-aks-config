resource "kubernetes_namespace" "management_namespace" {
  count = var.create_management_namespace ? 1 : 0
  metadata {
    name = "namespace-management"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
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
