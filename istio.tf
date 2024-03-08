locals {
  privatelink_service_mgmt_ingress_name = "PLS-${var.aks_cluster_name}-INGRESS-MGMT"
  privatelink_service_apps_ingress_name = "PLS-${var.aks_cluster_name}-INGRESS-APPS"
  privatelink_service_web_ingress_name  = "PLS-${var.aks_cluster_name}-INGRESS-WEB"
}

resource "kubernetes_namespace" "istio_system_namespace" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
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
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubernetes_namespace" "istio_ingress_mgmt_namespace" {
  metadata {
    name = "istio-ingress-mgmt"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
      "istio-injection"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubernetes_namespace" "istio_ingress_web_namespace" {
  metadata {
    name = "istio-ingress-web"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
      "istio-injection"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

data "kubectl_path_documents" "istio_crd_manifests" {
  pattern = "${path.module}/manifests/istio/crds/${lookup(var.charts.istio-base, "version", "")}/crd-all.gen.yaml"
}

# https://github.com/gavinbunney/terraform-provider-kubectl/issues/61
resource "kubectl_manifest" "istio_crd_install" {
  count     = length(split("\n---\n", file("${path.module}/manifests/istio/crds/${lookup(var.charts.istio-base, "version", "")}/crd-all.gen.yaml")))
  yaml_body = element(data.kubectl_path_documents.istio_crd_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubectl_manifest" "istio_operator_crd_install" {
  yaml_body = file("${path.module}/manifests/istio/crds/${lookup(var.charts.istio-base, "version", "")}/crd-operator.yaml")
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
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
    value = var.istio_components_hpa_spec.istiod_min_replicas
  }

  set {
    name  = "pilot.autoscaleMax"
    value = var.istio_components_hpa_spec.istiod_max_replicas
  }

  set {
    name  = "pilot.replicaCount"
    value = var.istio_components_hpa_spec.istiod_min_replicas
  }

  set {
    name  = "pilot.resources.requests.memory"
    value = var.istiod_memory_request
  }
  set {
    name  = "pilot.resources.requests.cpu"
    value = var.istiod_cpu_request
  }

  values = ["${file("${path.module}/manifests/istio/istiod_overrides.yaml")}"]

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.istio_ingress_namespace,
    helm_release.istio_base_install
  ]
}

# Ingress for mgmt services

resource "helm_release" "istio_ingress_mgmt_install" {
  name       = lookup(var.charts.istio-ingress, "name", "istio-ingress-mgmt")
  chart      = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  version    = lookup(var.charts.istio-ingress, "version", "")
  repository = "./install"
  namespace  = "istio-ingress-mgmt"

  set {
    name  = "gateways.istio-ingressgateway.name"
    value = "istio-ingressgateway-mgmt"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.app"
    value = "istio-ingressgateway-mgmt"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.istio"
    value = "ingressgateway-mgmt"
  }

  set {
    name  = "global.hub"
    value = "${var.acr_name}.azurecr.io/registry.hub.docker.com/istio"
  }

  set {
    name  = "global.defaultTolerations[0].key"
    value = var.systempool_taint_key
  }

  set {
    name  = "global.defaultTolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "global.defaultTolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "global.defaultNodeSelector.${var.istio_ingress_mgmt_node_selector.key}"
    value = var.istio_ingress_mgmt_node_selector.value
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleEnabled"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMin"
    value = var.istio_components_hpa_spec.istio_ingress_mgmt_min_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMax"
    value = var.istio_components_hpa_spec.istio_ingress_mgmt_max_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-create"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-name"
    value = local.privatelink_service_mgmt_ingress_name
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.istio_ingress_load_balancer_resource_group
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-proxy-protocol"
    value = var.enable_azure_pls_proxy_protocol
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.istio_ingress_mgmt_namespace,
    helm_release.istio_base_install,
    helm_release.istiod_install
  ]
}

# Ingress for apps

resource "helm_release" "istio_ingress_apps_install" {
  name       = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  chart      = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  version    = lookup(var.charts.istio-ingress, "version", "")
  repository = "./install"
  namespace  = "istio-ingress"

  set {
    name  = "gateways.istio-ingressgateway.name"
    value = "istio-ingressgateway-apps"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.app"
    value = "istio-ingressgateway-apps"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.istio"
    value = "ingressgateway-apps"
  }

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
    value = var.istio_components_hpa_spec.istio_ingress_apps_min_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMax"
    value = var.istio_components_hpa_spec.istio_ingress_apps_max_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-create"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-name"
    value = local.privatelink_service_apps_ingress_name
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.istio_ingress_load_balancer_resource_group
  }

  set {
    name  = "gateways.istio-ingressgateway.env.ISTIO_META_HTTP10"
    value = "1"
  }

  set {
    name  = "gateways.istio-ingressgateway.resources.requests.memory"
    value = var.isito_ingress_spec.resources.requests.memory
  }
  set {
    name  = "gateways.istio-ingressgateway.resources.limits.memory"
    value = var.isito_ingress_spec.resources.limits.memory
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

# Ingress for web
resource "helm_release" "istio_ingress_web_install" {
  name       = lookup(var.charts.istio-ingress, "name", "istio-ingress-web")
  chart      = lookup(var.charts.istio-ingress, "name", "istio-ingress")
  version    = lookup(var.charts.istio-ingress, "version", "")
  repository = "./install"
  namespace  = "istio-ingress-web"

  set {
    name  = "gateways.istio-ingressgateway.name"
    value = "istio-ingressgateway-web"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.app"
    value = "istio-ingressgateway-web"
  }

  set {
    name  = "gateways.istio-ingressgateway.labels.istio"
    value = "ingressgateway-web"
  }

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
    value = var.istio_components_hpa_spec.istio_ingress_web_min_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.autoscaleMax"
    value = var.istio_components_hpa_spec.istio_ingress_web_max_replicas
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-create"
    value = "true"
  }

  set {
    name  = "gateways.istio-ingressgateway.serviceAnnotations.service\\.beta\\.kubernetes\\.io/azure-pls-name"
    value = local.privatelink_service_web_ingress_name
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
    kubernetes_namespace.istio_ingress_web_namespace,
    helm_release.istio_base_install,
    helm_release.istiod_install
  ]
}

data "kubectl_file_documents" "istio_ingress_gateway_apps_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_ingress_gateway_apps.yaml", {
    istio_gateway_apps_cert_secret_name = var.istio_gateway_apps_cert_secret_name
    istio_ingress_apps_domains          = var.istio_ingress_apps_domains
    aks_cluster_name                    = var.aks_cluster_name
  })
}

data "kubectl_file_documents" "istio_ingress_gateway_mgmt_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_ingress_gateway_mgmt.yaml", {
    istio_gateway_mgmt_cert_secret_name = var.istio_gateway_mgmt_cert_secret_name
    istio_ingress_mgmt_domains          = var.istio_ingress_mgmt_domains
    aks_cluster_name                    = var.aks_cluster_name
  })
}

data "kubectl_file_documents" "istio_ingress_gateway_web_manifests" {
  content = templatefile("${path.module}/manifests/istio/istio_ingress_gateway_web.yaml", {
    istio_gateway_web_cert_secret_name = var.istio_gateway_web_cert_secret_name
    istio_ingress_web_domains          = var.istio_ingress_web_domains
    aks_cluster_name                   = var.aks_cluster_name
  })
}

resource "kubectl_manifest" "install_istio_ingress_gateway_apps_manifests" {
  count     = length(data.kubectl_file_documents.istio_ingress_gateway_apps_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_ingress_gateway_apps_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    helm_release.istio_ingress_apps_install
  ]
}

resource "kubectl_manifest" "install_istio_ingress_gateway_mgmt_manifests" {
  count     = length(data.kubectl_file_documents.istio_ingress_gateway_mgmt_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_ingress_gateway_mgmt_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    helm_release.istio_ingress_mgmt_install
  ]
}

resource "kubectl_manifest" "install_istio_ingress_gateway_web_manifests" {
  count     = length(data.kubectl_file_documents.istio_ingress_gateway_web_manifests.documents)
  yaml_body = element(data.kubectl_file_documents.istio_ingress_gateway_web_manifests.documents, count.index)
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubectl_manifest.cert-manager-install,
    kubectl_manifest.cert_issuer_install,
    helm_release.istio_ingress_web_install
  ]
}

# PeerAuthentication menifest - Enable mtls
resource "kubectl_manifest" "enable_mtls" {
  yaml_body = templatefile("${path.module}/manifests/istio/istio_peerauthentication.yaml", {
    istio_peer_authentication_mode = var.istio_peer_authentication_mode
  })
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubernetes_namespace.istio_system_namespace,
    time_sleep.wait_for_istio_crds,
    helm_release.istio_base_install
  ]
}

# Enable envoy access logs
resource "kubectl_manifest" "istio_telemetry" {
  yaml_body = file("${path.module}/manifests/istio/telemetry.yaml")
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    kubernetes_namespace.istio_system_namespace,
    time_sleep.wait_for_istio_crds,
    helm_release.istio_base_install
  ]
}

# Enable PROXY PROTOCOL with EnvoyFilter
resource "kubectl_manifest" "istio_envoy_filter" {
  count     = var.enable_azure_pls_proxy_protocol ? 1 : 0
  yaml_body = file("${path.module}/manifests/istio/istio_envoy_filter.yaml")
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [kubectl_manifest.istio_telemetry]
}

# Enable AuthorizationPolicy if list is not empty.
resource "kubectl_manifest" "istio_authorizationPolicy" {
  count = length(var.src_ip_range) < 1 ? 0 : 1
  yaml_body = templatefile("${path.module}/manifests/istio/istio_authorizationpolicy.yaml", {
    src_ip_range = var.src_ip_range
  })
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [kubectl_manifest.istio_telemetry]
}

resource "null_resource" "ingress_apps" {
  triggers = {
    resource_1 = helm_release.istio_ingress_apps_install.id
    resource_2 = kubectl_manifest.install_istio_ingress_gateway_apps_manifests[0].id
  }
}

resource "null_resource" "ingress_mgmt" {
  triggers = {
    resource_1 = helm_release.istio_ingress_mgmt_install.id
    resource_2 = kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests[0].id
  }
}

resource "null_resource" "ingress_web" {
  triggers = {
    resource_1 = helm_release.istio_ingress_web_install.id
    resource_2 = kubectl_manifest.install_istio_ingress_gateway_web_manifests[0].id
  }
}
