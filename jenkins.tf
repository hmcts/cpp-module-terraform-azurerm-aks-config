resource "kubernetes_namespace" "jenkins_namespace" {
  count = var.create_jenkins_namespace ? 1 : 0
  metadata {
    name = "jenkins"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      # "istio-injection"              = "disabled" Disabling for now due to EI-1792
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubectl_manifest" "jenkins_deploy_rolebinding" {
  count     = var.create_jenkins_namespace ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-deploy
  namespace: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-deploy
subjects:
- kind: ServiceAccount
  name: jenkins-deploy
  namespace: kube-system
- kind: ServiceAccount
  name: default
  namespace: jenkins
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubernetes_namespace.jenkins_namespace[0],
    helm_release.aks_rbac
  ]
}
