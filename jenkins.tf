resource "kubernetes_namespace" "jenkins_namespace" {
  count = var.create_jenkins_namespace ? 1 : 0
  metadata {
    name = "jenkins"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "istio-injection"              = "enabled"
    }
  }
}