resource "kubernetes_namespace" "istio_system_namespace" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
}

resource "kubernetes_namespace" "istio_ingress_namespace" {
  metadata {
    name = "istio-ingress"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
      "istio-injection"              = "enabled"
    }
  }
}

data "kubectl_file_documents" "istio_crd_manifests" {
  content = templatefile("${path.module}/manifests/istio/crds/${lookup(var.charts.istio-base, "version", "")}/crd-all.gen.yaml", {})
}

resource "kubectl_manifest" "istio_crd_install" {
  count     = length(data.kubectl_file_documents.istio_crd_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_crd_manifests.documents, count.index)
}

resource "kubectl_manifest" "istio_operator_crd_install" {
  yaml_body = file("${path.module}/manifests/istio/crds/${lookup(var.charts.istio-base, "version", "")}/crd-operator.yaml")
}

resource "time_sleep" "wait_for_istio_crds" {
  depends_on = [
    kubectl_manifest.istio_crd_install,
    kubectl_manifest.istio_operator_crd_install
  ]
  triggers = {
    istio_crds_id = join(",", kubectl_manifest.istio_crd_install.*.uid)
  }

  create_duration = "30s"
}

resource "helm_release" "istio_base_install" {
  name       = lookup(var.charts.istio-base, "name", "istio-base")
  chart      = lookup(var.charts.istio-base, "name", "istio-base")
  version    = lookup(var.charts.istio-base, "version", "")
  repository = "./install"
  namespace  = "istio-system"

  set {
    name  = "global.istioNamespace"
    value = "istio-system"
  }

  skip_crds = true

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.istio_system_namespace,
    time_sleep.wait_for_istio_crds
  ]
}

resource "helm_release" "istiod_install" {
  name       = lookup(var.charts.istiod, "name", "istiod")
  chart      = lookup(var.charts.istiod, "name", "istiod")
  version    = lookup(var.charts.istiod, "version", "")
  repository = "./install"
  namespace  = "istio-system"

  set {
    name  = "global.istioNamespace"
    value = "istio-system"
  }

  set {
    name  = "global.hub"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/istio"
  }

  set {
    name  = "pilot.tolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "pilot.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "pilot.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "pilot.nodeSelector.${var.istiod_node_selector.key}"
    value = var.istiod_node_selector.value
  }

  set {
    name  = "pilot.autoscaleEnabled"
    value = "true"
  }

  set {
    name  = "pilot.autoscaleMin"
    value = var.istio_components_hpa_spec.min_replicas
  }

  set {
    name  = "pilot.autoscaleMax"
    value = var.istio_components_hpa_spec.max_replicas
  }

  set {
    name  = "pilot.replicaCount"
    value = var.istio_components_hpa_spec.min_replicas
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.istio_ingress_namespace,
    helm_release.istio_base_install
  ]
}

resource "helm_release" "istio_ingress_install" {
  name       = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  chart      = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  version    = lookup(var.charts.istio-ingress, "version", "")
  repository = "./install"
  namespace  = "istio-ingress"

  set {
    name  = "global.hub"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/istio"
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleEnabled"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMin"
    value = var.istio_components_hpa_spec.min_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMax"
    value = var.istio_components_hpa_spec.max_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.istio_ingress_load_balancer_resource_group
  }

  set {
    name  = "gateways.istio-ingressgateway.env.ISTIO_META_HTTP10"
    value = "1"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.istio_ingress_namespace,
    helm_release.istio_base_install,
    helm_release.istiod_install
  ]
}

# Istio gateway manifests
data "kubectl_file_documents" "istio_ingress_gateway_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_ingress_gateway.yaml", {
    ingress-gateway-secret = var.istio_gateway_cert_secret_name
    ingressdomain          = var.ingressdomain
    aks_cluster_name       = var.aks_cluster_name
  })
}

resource "kubectl_manifest" "install_istio_ingress_gateway_manifests" {
  count     = length(data.kubectl_file_documents.istio_ingress_gateway_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_ingress_gateway_manifests.documents, count.index)
  override_namespace = "istio-ingress"
  depends_on = [
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    helm_release.istio_ingress_install
  ]
}

# PeerAuthentication menifest - Enable mtls 
resource "kubectl_manifest" "enable_mtls" {
  yaml_body = file("${path.module}/manifests/istio/istio_peerauthentication.yaml")
}

# Enable envoy access logs
resource "kubectl_manifest" "istio_telemetry" {
  yaml_body = file("${path.module}/manifests/istio/telemetry.yaml")
}
