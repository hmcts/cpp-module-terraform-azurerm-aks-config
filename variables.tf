variable "istiod_node_selector" {
  description = "Node selector key and value to install istiod"
  type        = map(string)
  default = {
    key   = "agentpool"
    value = "sysagentpool"
  }
}

variable "istio_ingress_mgmt_node_selector" {
  description = "Node selector key and value to install istiod"
  type        = map(string)
  default = {
    key   = "agentpool"
    value = "sysagentpool"
  }
}

variable "systempool_taint_key" {
  description = "system pool taint key"
  type        = string
  default     = "CriticalAddonsOnly"
}

variable "node_affinity_exp_key" {
  description = "node affinity expession key for systempool label"
  type        = string
  default     = "nodepool"
}

variable "node_affinity_exp_value" {
  description = "node affinity expession value for systempool label"
  type        = string
  default     = "control_plane_node"
}

variable "istio_ingress_load_balancer_resource_group" {
  description = "Resource group name where the load balancer to be installed"
  type        = string
}

variable "dynatrace_api" {
  description = "Dynatrace api endpoint to configure for Dynakube custom resource "
  type        = string
}

variable "dynatrace_api_token" {
  description = "Dynatrace api token to configure for Dynakube custom resource "
  type        = string
}

variable "dynatrace_paas_token" {
  description = "Dynatrace paas token to configure for Dynakube custom resource "
  type        = string
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "environment_type" {
  type        = string
  description = "Environment type - nonlive/live"
}

variable "istio_ingress_apps_domain" {
  type        = string
  description = "Ingress domain name FQDN for apps"
}

variable "istio_ingress_mgmt_domain" {
  type        = string
  description = "Ingress domain name FQDN for mgmt"
}

variable "kiali_hostname_prefix" {
  type        = string
  description = "Hostname prefix to access kiali"
  default = "kiali"
}

variable "prometheus_hostname_prefix" {
  type        = string
  description = "Hostname prefix to access kiali"
  default = "prometheus"
}

variable "grafana_hostname_prefix" {
  type        = string
  description = "Hostname prefix to access kiali"
  default = "grafana"
}

variable "acr_name" {
  type        = string
  description = "ACR name to pull the charts from"
}

variable "acr_user_name" {
  type        = string
  description = "ACR username"
}

variable "acr_user_password" {
  type        = string
  description = "ACR password"
}

variable "aks_resource_group_name" {
  type        = string
  description = "AKS cluster resource group name"
}

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name"
}

variable "aks_cluster_location" {
  type        = string
  description = "Geo location where AKS is deployed"
  default     = "uksouth"
}

variable "aks_ca_certificate" {
  type        = string
  description = "AKS CA certtificate"
}

variable "aks_server_endpoint" {
  type        = string
  description = "AKS server endpoint"
}

variable "istio_gateway_cert_issuer" {
  type        = string
  description = "cpp-nonlive"
}

variable "istio_gateway_mgmt_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-mgmt-cert"
}

variable "istio_gateway_apps_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-apps-cert"
}

variable "istio_components_hpa_spec" {
  type = map(number)
  default = {
    istiod_min_replicas = 1
    istiod_max_replicas = 5
    istio_ingress_mgmt_min_replicas = 1
    istio_ingress_mgmt_max_replicas = 5
    istio_ingress_apps_min_replicas = 1
    istio_ingress_apps_max_replicas = 5
  }
}

variable "dynatrace_components_hpa_spec" {
  type = map(number)
  default = {
    min_replicas        = 1
    max_replicas        = 2
    avg_cpu_utilization = 80
    avg_mem_utilization = 80
  }
}

variable "filebeat_namespace" {
  type        = string
  description = "Namespace for filebeat"
}

variable "charts" {
  type = object({
    namespace          = map(string)
    jenkins-rbac       = map(string)
    user-rbac          = map(string)
    istio-base         = map(string)
    istiod             = map(string)
    istio-ingress      = map(string)
    filebeat-mgm       = map(string)
    filebeat-app       = map(string)
    kiali-operator     = map(string)
    prometheus         = map(string)
    prometheus-adapter = map(string)
  })
  default = {
    namespace = {
      path    = "charts/namespace"
      version = "0.3.1"
    },
    jenkins-rbac = {
      path    = "charts/jenkins-rbac"
      version = "1.0.1"
    },
    user-rbac = {
      path    = "charts/user-rbac"
      version = "1.0.0"
    },
    istio-base = {
      path    = "charts/istio-base"
      version = "1.13.2"
    },
    istiod = {
      path    = "charts/istiod"
      version = "1.13.2"
    },
    istio-ingress = {
      path    = "charts/istio-ingress"
      version = "1.13.2"
    },
    filebeat-mgm = {
      path    = "charts/filebeat"
      version = "1.0.0"
    },
    filebeat-app = {
      path    = "charts/filebeat"
      version = "1.0.1"
    },
    kiali-operator = {
      path    = "charts/kiali-operator"
      version = "0.1.0"
    },
    prometheus = {
      path    = "charts/kube-prometheus-stack"
      version = "32.3.0"
    },
    prometheus-adapter = {
      path    = "charts/prometheus-adapter"
      version = "3.0.2"
    },
  }
}

variable "user_rbac" {
  type = map(list(string))
  default = {
    aks_reader_members_ids        = []
    aks_contributor_members_ids   = []
    aks_cluster_admin_members_ids = []
  }
}

variable "workspace_resource_group_name" {
  type        = string
  description = "resource grpup where workspace is created"
  default     = null
}

variable "action_group_name" {
  type        = string
  description = "resource grpup where workspace is created"
  default     = "platformDevNotify"
}

variable "omsagent" {
  type = object({
    log_collection_settings_stdout_enabled = string
    log_collection_settings_stderr_enabled = string
  })
  default = {
    log_collection_settings_stdout_enabled = "false"
    log_collection_settings_stderr_enabled = "false"
  }
}

variable "alerts" {
  type = object({
    enable_alerts = bool
    infra = object({
      enabled                  = bool
      cpu_usage_threshold      = number
      disk_usage_threshold     = number
      node_limit_threshold     = number
      cluster_health_threshold = number
    })
    sys_workload = object({
      enabled    = bool
      daemonset  = map(number)
      deployment = map(number)
    })
    apps_workload = object({
      enabled            = bool
      deployment         = map(number)
      hpa_min_replica    = map(number)
      hpa_max_replica    = map(number)
      cluster_agent_pool = map(number)
    })
  })
  default = {
    enable_alerts = true
    infra = {
      enabled                  = true
      cpu_usage_threshold      = 80
      disk_usage_threshold     = 80
      node_limit_threshold     = 0
      cluster_health_threshold = 1
    }
    sys_workload = {
      enabled = true
      daemonset = {
        severity    = 1
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      deployment = {
        severity    = 1
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
    }
    apps_workload = {
      enabled = true
      deployment = {
        severity    = 1
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      hpa_min_replica = {
        severity    = 1
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      hpa_max_replica = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      cluster_agent_pool = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
    }
  }
}

variable "vault_token" {
  type        = string
  description = "AKS server endpoint"
}

variable "vault_path" {
  type        = string
  description = "AKS server endpoint"
}

variable "vault_url" {
  type        = string
  description = "AKS server endpoint"
}

variable "ca_bundle_path" {
  type        = string
  description = "ca bundle path to trust the Vault connection"
}

variable "worker_agents_pool_name" {
  description = "The AKS worker agentpool (nodepool) name."
  type        = string
  default     = "wrkagentpool"
}

variable "enable_dynatrace" {
  type        = bool
  description = "enable dynatrace monitoring of cluster"
  default     = true
}

variable "dynatrace_networkzone" {
  description = "Dynatrace api endpoint to configure for Dynakube custom resource "
  type        = string
}

variable "monitor_config" {
  type = map(string)
}

variable "prometheus" {
  type = object({
    grafana_image_tag                    = string
    grafana_k8s_sidecar_image_tag        = string
    kube_state_metrics_image_tag         = string
    node_exporter_image_tag              = string
    prometheus_operator_image_tag        = string
    prometheus_config_reloader_image_tag = string
    kube_webhook_certgen_image_tag       = string
    prometheus_image_tag                 = string
    prometheus_retention                 = string
    prometheus_storage_class_name        = string
    prometheus_storage_size              = string
  })
  default = {
    grafana_image_tag                    = "8.3.5"
    grafana_k8s_sidecar_image_tag        = "1.15.1"
    kube_state_metrics_image_tag         = "v2.3.0"
    node_exporter_image_tag              = "v1.3.1"
    prometheus_operator_image_tag        = "v0.54.0"
    prometheus_config_reloader_image_tag = "v0.54.0"
    kube_webhook_certgen_image_tag       = "v1.0"
    prometheus_image_tag                 = "v2.33.1"
    prometheus_retention                 = "15d"
    prometheus_storage_class_name        = "managed-premium"
    prometheus_storage_size              = "100Gi"
  }
}