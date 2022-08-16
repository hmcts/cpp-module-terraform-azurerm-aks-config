data "azurerm_client_config" "current" {}

resource "kubectl_manifest" "delete_validation_ns" {
  count = var.delete_validation_ns ? 1: 0
  yaml_body = file("${path.module}/manifests/common/delete_validation_ns.yaml")
}