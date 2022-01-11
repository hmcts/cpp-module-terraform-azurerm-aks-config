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
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    time_sleep.wait_for_istio_crds
  ]
}