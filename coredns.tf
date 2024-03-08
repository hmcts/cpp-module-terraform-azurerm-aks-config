locals {
  addns = lookup(var.addns, var.environment_type, null)
}

resource "kubectl_manifest" "custom_coredns" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  ${var.environment_type}.server: |
    ${local.addns.domain}:53 {
      errors
      cache 30
      forward . ${local.addns.resolvers}
    }
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}
