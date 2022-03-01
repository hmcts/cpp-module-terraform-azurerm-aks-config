resource "kubernetes_namespace" "prometheus_namespace" {
  metadata {
    name = "prometheus"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "filebeat_enable"              = "enabled"
    }
  }
}

data "vault_generic_secret" "grafana_spn_creds" {
  path = "secret/mgmt/spn_k8s_monitor"
}

resource "helm_release" "prometheus" {
  name    = lookup(var.charts.prometheus, "name", "kube-prometheus-stack")
  chart   = lookup(var.charts.prometheus, "name", "kube-prometheus-stack")
  version = lookup(var.charts.prometheus, "version", "")
  values = [templatefile("${path.module}/chart-values/prometheus.tmpl", {
    grafana_image                        = "${var.acr_name}.azurecr.io/grafana/grafana"
    grafana_image_tag                    = var.prometheus.grafana_image_tag
    grafana_k8s_sidecar_image            = "${var.acr_name}.azurecr.io/quay.io/kiwigrid/k8s-sidecar"
    grafana_k8s_sidecar_image_tag        = var.prometheus.grafana_k8s_sidecar_image_tag
    grafana_auth_azuread_client_id       = data.vault_generic_secret.grafana_spn_creds.data["client_id"]
    grafana_auth_azuread_client_secret   = data.vault_generic_secret.grafana_spn_creds.data["client_secret"]
    grafana_auth_azuread_tenant_id       = data.azurerm_client_config.current.tenant_id
    kube_state_metrics_image             = "${var.acr_name}.azurecr.io/k8s.gcr.io/kube-state-metrics/kube-state-metrics"
    kube_state_metrics_image_tag         = var.prometheus.kube_state_metrics_image_tag
    node_exporter_image                  = "${var.acr_name}.azurecr.io/quay.io/prometheus/node-exporter"
    node_exporter_image_tag              = var.prometheus.node_exporter_image_tag
    prometheus_operator_image            = "${var.acr_name}.azurecr.io/quay.io/prometheus-operator/prometheus-operator"
    prometheus_operator_image_tag        = var.prometheus.prometheus_operator_image_tag
    prometheus_config_reloader_image     = "${var.acr_name}.azurecr.io/quay.io/prometheus-operator/prometheus-config-reloader"
    prometheus_config_reloader_image_tag = var.prometheus.prometheus_config_reloader_image_tag
    kube_webhook_certgen_image           = "${var.acr_name}.azurecr.io/k8s.gcr.io/ingress-nginx/kube-webhook-certgen"
    kube_webhook_certgen_image_tag       = var.prometheus.kube_webhook_certgen_image_tag
    prometheus_image                     = "${var.acr_name}.azurecr.io/quay.io/prometheus/prometheus"
    prometheus_image_tag                 = var.prometheus.prometheus_image_tag
    prometheus_retention                 = var.prometheus.prometheus_retention
    prometheus_storage_class_name        = var.prometheus.prometheus_storage_class_name
    prometheus_storage_size              = var.prometheus.prometheus_storage_size
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