resource "kubernetes_namespace" "cert_manager_namespace" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

data "kubectl_path_documents" "cert_manager_manifests" {
  pattern = "${path.module}/manifests/cert-manager/cert-manager.yaml"
  vars = {
    docker_image_certmanager_cainjector = "${var.acr_name}.azurecr.io/quay.io/jetstack/cert-manager-cainjector"
    docker_image_certmanager_controller = "${var.acr_name}.azurecr.io/quay.io/jetstack/cert-manager-controller"
    docker_image_certmanager_webhook    = "${var.acr_name}.azurecr.io/quay.io/jetstack/cert-manager-webhook"
    docker_tag_certmanager              = "v1.6.1"
  }
}

# https://github.com/gavinbunney/terraform-provider-kubectl/issues/61
resource "kubectl_manifest" "cert-manager-install" {
  count      = length(split("\n---\n", file("${path.module}/manifests/cert-manager/cert-manager.yaml")))
  yaml_body  = element(data.kubectl_path_documents.cert_manager_manifests.documents, count.index)
  depends_on = [kubernetes_namespace.cert_manager_namespace]
}

resource "time_sleep" "wait_for_certmanager_install" {
  depends_on = [
    kubectl_manifest.cert-manager-install
  ]
  create_duration = "20s"
}

data "kubectl_file_documents" "cert_issuer_manifests" {
  content = templatefile("${path.module}/manifests/cert-manager/cert-issuer.yaml", {
    vault_token                         = base64encode(var.vault_token)
    vault_path                          = var.vault_path
    vault_url                           = var.vault_url
    ca_bundle                           = data.vault_generic_secret.ca_cert.data.issuing_ca
    istio_gateway_mgmt_cert_secret_name = var.istio_gateway_mgmt_cert_secret_name
    istio_gateway_apps_cert_secret_name = var.istio_gateway_apps_cert_secret_name
    istio_gateway_web_cert_secret_name  = var.istio_gateway_web_cert_secret_name
    istio_ingress_apps_domains          = var.istio_ingress_apps_domains
    istio_ingress_mgmt_domains          = var.istio_ingress_mgmt_domains
    istio_ingress_web_domains           = var.istio_ingress_web_domains
  })
}

resource "kubectl_manifest" "cert_issuer_install" {
  count      = length(split("\n---\n", file("${path.module}/manifests/cert-manager/cert-issuer.yaml")))
  yaml_body  = element(data.kubectl_file_documents.cert_issuer_manifests.documents, count.index)
  depends_on = [kubectl_manifest.cert-manager-install, time_sleep.wait_for_certmanager_install]
}
