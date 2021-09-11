resource "vault_pki_secret_backend_cert" "istio_gateway_create_cert" {
  backend     = "pki"
  name        = var.istio_gateway_cert_issuer
  common_name = var.ingressdomain
  ttl         = "8760h"
  # auto_renew  = true
  # min_seconds_remaining = 5184000
}

resource "kubernetes_secret" "istio_gateway_cert_secret" {
  metadata {
    name      = var.istio_gateway_cert_secret_name
    namespace = "istio-system"
  }

  data = {
    "tls.crt" = vault_pki_secret_backend_cert.istio_gateway_create_cert.certificate
    "tls.key" = vault_pki_secret_backend_cert.istio_gateway_create_cert.private_key
  }

  type = "kubernetes.io/tls"
  depends_on = [
    kubernetes_namespace.istio_namespace
  ]
}

data "kubectl_file_documents" "istio_gateway_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_gateway.yaml", {
    ingress-gateway-secret = var.istio_gateway_cert_secret_name
    ingressdomain          = var.ingressdomain
    aks_cluster_name       = var.aks_cluster_name
  })
}

resource "kubectl_manifest" "istio_gateway_manifest" {
  count     = length(data.kubectl_file_documents.istio_gateway_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_gateway_manifests.documents, count.index)
  depends_on = [
    kubernetes_secret.istio_gateway_cert_secret,
    time_sleep.wait_for_istio_crds
  ]
}