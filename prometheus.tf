resource "kubernetes_namespace" "prometheus_namespace" {
  metadata {
    name = "prometheus"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

data "vault_generic_secret" "grafana_spn_creds" {
  path = "secret/mgmt/spn_k8s_monitor"
}

resource "helm_release" "prometheus" {
  name    = lookup(var.charts.prometheus, "name", "kube-prometheus-stack")
  chart   = lookup(var.charts.prometheus, "name", "kube-prometheus-stack")
  version = lookup(var.charts.prometheus, "version", "")
  values = [templatefile("${path.module}/chart-values/prometheus.tmpl", {
    grafana_image_registry                      = "${var.acr_name}.azurecr.io/docker.io"
    grafana_image_repository                    = "grafana/grafana"
    grafana_image_tag                           = var.prometheus.grafana_image_tag
    grafana_k8s_sidecar_image_registry          = "${var.acr_name}.azurecr.io/quay.io"
    grafana_k8s_sidecar_image_repository        = "kiwigrid/k8s-sidecar"
    grafana_k8s_sidecar_image_tag               = var.prometheus.grafana_k8s_sidecar_image_tag
    grafana_url                                 = "https://${var.grafana_hostnames[1]}"
    grafana_auth_azuread_client_id              = data.vault_generic_secret.grafana_spn_creds.data["client_id"]
    grafana_auth_azuread_client_secret          = data.vault_generic_secret.grafana_spn_creds.data["client_secret"]
    grafana_auth_azuread_tenant_id              = data.azurerm_client_config.current.tenant_id
    kube_state_metrics_image_registry           = "${var.acr_name}.azurecr.io/registry.k8s.io"
    kube_state_metrics_image_repository         = "kube-state-metrics/kube-state-metrics"
    kube_state_metrics_image_tag                = var.prometheus.kube_state_metrics_image_tag
    node_exporter_image_registry                = "${var.acr_name}.azurecr.io/quay.io"
    node_exporter_image_repository              = "prometheus/node-exporter"
    node_exporter_image_tag                     = var.prometheus.node_exporter_image_tag
    prometheus_operator_image_registry          = "${var.acr_name}.azurecr.io/quay.io"
    prometheus_operator_image_repository        = "prometheus-operator/prometheus-operator"
    prometheus_operator_image_tag               = var.prometheus.prometheus_operator_image_tag
    prometheus_config_reloader_image_registry   = "${var.acr_name}.azurecr.io/quay.io"
    prometheus_config_reloader_image_repository = "prometheus-operator/prometheus-config-reloader"
    prometheus_config_reloader_image_tag        = var.prometheus.prometheus_config_reloader_image_tag
    kube_webhook_certgen_image_registry         = "${var.acr_name}.azurecr.io/k8s.gcr.io"
    kube_webhook_certgen_image_repository       = "ingress-nginx/kube-webhook-certgen"
    kube_webhook_certgen_image_tag              = var.prometheus.kube_webhook_certgen_image_tag
    prometheus_image_registry                   = "${var.acr_name}.azurecr.io/quay.io"
    prometheus_image_repository                 = "prometheus/prometheus"
    prometheus_replica                          = var.prometheus.prometheus_replica
    prometheus_image_tag                        = var.prometheus.prometheus_image_tag
    prometheus_retention                        = var.prometheus.prometheus_retention
    prometheus_storage_class_name               = var.prometheus.prometheus_storage_class_name
    prometheus_storage_size                     = var.prometheus.prometheus_storage_size
    drop_envoy_stats_for_context_pods           = var.prometheus.prometheus_drop_envoy_stats_for_context_pods
    grafana_storage_class_name                  = var.prometheus.grafana_storage_class_name
    grafana_storage_size                        = var.prometheus.grafana_storage_size
  })]
  repository        = "./install"
  namespace         = "prometheus"
  dependency_update = true
  wait              = true
  timeout           = 600
  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.prometheus_namespace
  ]
}

resource "helm_release" "prometheus_adapter_install" {
  name       = lookup(var.charts.prometheus-adapter, "name", "prometheus-adapter")
  chart      = lookup(var.charts.prometheus-adapter, "name", "prometheus-adapter")
  version    = lookup(var.charts.prometheus-adapter, "version", "")
  repository = "./install"
  namespace  = "prometheus"

  values = [templatefile("${path.module}/chart-values/prometheus-adapter.tmpl", {
    acr_name = var.acr_name
  })]

  wait    = true
  timeout = 300

  depends_on = [null_resource.download_charts, helm_release.prometheus]
}

resource "kubectl_manifest" "install_grafana_virtualservice_manifests" {
  yaml_body = templatefile("${path.module}/manifests/prometheus/virtualservice_grafana.yaml", {
    namespace           = "prometheus"
    gateway             = "istio-ingress-mgmt/istio-ingressgateway-mgmt"
    grafana_hostnames   = var.grafana_hostnames
    grafana_destination = "${helm_release.prometheus.name}-grafana"
  })
  override_namespace = "prometheus"
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [
    helm_release.prometheus,
    helm_release.prometheus_adapter_install,
    kubectl_manifest.install_istio_ingress_gateway_mgmt_manifests
  ]
}
