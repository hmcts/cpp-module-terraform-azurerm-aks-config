data "kubectl_file_documents" "cert_manager_manifests" {
  content = templatefile("${path.module}/manifests/cert-manager/cert-manager.yaml", {})
}

resource "kubectl_manifest" "cert-manager-install" {
  count     = length(data.kubectl_file_documents.cert_manager_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.cert_manager_manifests.documents, count.index)
}

data "kubectl_file_documents" "cert_issuer_manifests" {
  content = templatefile("${path.module}/manifests/cert-manager/cert-issuer.yaml", {
    vault_token  = base64encode(var.vault_token)
    vault_path   = var.vault_path
    vault_url    = var.vault_url
    ca_bundle    = filebase64(var.ca_bundle_path)
    ingress-gateway-secret = var.istio_gateway_cert_secret_name
    ingressdomain          = var.ingressdomain
  })
}

resource "kubectl_manifest" "cert_issuer_install" {
  count     = length(data.kubectl_file_documents.cert_issuer_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.cert_issuer_manifests.documents, count.index)
  depends_on = [kubectl_manifest.cert-manager-install]
}