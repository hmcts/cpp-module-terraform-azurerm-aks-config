resource "vault_pki_secret_backend_cert" "app" {
  backend     = "pki"
  name        = "cpp-nonlive"
  common_name = var.ingressdomain
}

resource "kubernetes_secret" "k8s_secret" {
  metadata {
    name      = "istio-ingressgateway-certs"
    namespace = "istio-system"
  }

  data = {
    "tls.crt" = base64encode(vault_pki_secret_backend_cert.app.certificate)
    "tls.key" = base64encode(vault_pki_secret_backend_cert.app.private_key)
  }

  type = "kubernetes.io/tls"
  depends_on = [
    kubernetes_namespace.istio_namespace
  ]
}

resource "kubectl_manifest" "istio_gateway_manifest" {
  yaml_body = templatefile("${path.module}/manifests/gateway_config.yaml",
    {
      ingress-gateway-secret = kubernetes_secret.k8s_secret.name
      ingressdomain          = var.ingressdomain
  })

  depends_on = [
    helm_release.istio_operator_install,
    kubernetes_namespace.istio_namespace
  ]
}
