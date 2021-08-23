resource "vault_pki_secret_backend_cert" "istio_gateway_create_cert" {
  backend     = "pki"
  name        = var.istio_gateway_cert_issuer
  common_name = var.ingressdomain
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

resource "kubectl_manifest" "istio_gateway_manifest" {
  yaml_body = templatefile("${path.module}/manifests/istio_gateway_config.yaml",
    {
      ingress-gateway-secret = var.istio_gateway_cert_secret_name
      ingressdomain          = var.ingressdomain
  })

  depends_on = [
    helm_release.istio_operator_install,
    kubernetes_namespace.istio_namespace,
    kubernetes_secret.istio_gateway_cert_secret
  ]
}
