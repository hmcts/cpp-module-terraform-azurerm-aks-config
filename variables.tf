variable "istiod_node_selector" {
  description = "Node selector key and value to install istiod"
  type        = map(string)
  default = {
    key   = "agentpool"
    value = "sysagentpool"
  }
}

variable "dynatrace_operator_node_selector" {
  description = "Node selector key and value to install dynatrace operator"
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

variable "istio_ingress_apps_domains" {
  type        = list(string)
  description = "Ingress domain name FQDN for apps"
}

variable "istio_ingress_mgmt_domains" {
  type        = list(string)
  description = "Ingress domain name FQDN for mgmt"
}

variable "istio_ingress_web_domains" {
  type        = list(string)
  description = "Ingress domain name FQDN for web"
}

variable "kiali_hostnames" {
  type        = list(string)
  description = "Hostnames used for kiali"
}

variable "prometheus_hostname_prefix" {
  type        = string
  description = "Hostname prefix to access kiali"
  default     = "prometheus"
}

variable "grafana_hostnames" {
  type        = list(string)
  description = "Hostnames for access to Grafana"
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

variable "istio_gateway_mgmt_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-mgmt-cert"
}

variable "istio_gateway_apps_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-apps-cert"
}

variable "istio_gateway_web_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-web-cert"
}

variable "istio_components_hpa_spec" {
  type = map(number)
  default = {
    istiod_min_replicas             = 1
    istiod_max_replicas             = 5
    istio_ingress_mgmt_min_replicas = 1
    istio_ingress_mgmt_max_replicas = 5
    istio_ingress_apps_min_replicas = 1
    istio_ingress_apps_max_replicas = 5
    istio_ingress_web_min_replicas  = 1
    istio_ingress_web_max_replicas  = 5
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
    aks-rbac               = map(string)
    istio-base             = map(string)
    istiod                 = map(string)
    istio-ingress          = map(string)
    filebeat-mgm           = map(string)
    filebeat-app           = map(string)
    kiali-operator         = map(string)
    prometheus             = map(string)
    prometheus-adapter     = map(string)
    dynatrace-operator     = map(string)
    overprovisioning       = map(string)
    gatekeeper             = map(string)
    pgadmin                = map(string)
    velero                 = map(string)
    keda                   = map(string)
    sonarqube              = map(string)
    smashing               = map(string)
    azure-service-operator = map(string)
  })
  default = {
    aks-rbac = {
      path    = "charts/aks-rbac"
      version = "1.0.1"
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
    dynatrace-operator = {
      path    = "charts/dynatrace-operator"
      version = "0.5.1"
    },
    overprovisioning = {
      path    = "charts/overprovisioning"
      version = "0.1.0"
    },
    gatekeeper = {
      path    = "charts/gatekeeper"
      version = "3.10.0"
    },
    velero = {
      path    = "charts/velero"
      version = "3.1.0"
    },
    pgadmin = {
      path    = "charts/pgadmin"
      version = "0.1.0"
    },
    sonarqube = {
      path    = "charts/sonarqube"
      version = "9.9.2"
    },
    smashing = {
      path    = "charts/smashing"
      version = "0.1.2"
    },
    azure-service-operator = {
      path    = "charts/azure-service-operator"
      version = "v2.3.0"
    },
    keda = {
      path    = "charts/keda"
      version = "2.13.0"
    },
  }
}

variable "overprovisioning" {
  type = object({
    enable        = bool
    replica_count = number
    resources = object({
      requests = map(string)
      limits   = map(string)
    })
  })
  default = {
    enable        = false
    replica_count = 1
    resources = {
      requests = {
        cpu    = "6"
        memory = "16Gi"
      }
      limits = {
        cpu    = "6"
        memory = "16Gi"
      }
    }
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

variable "aks_rbac_namespace" {
  type        = string
  description = "namespace where to store configmap with AKS Groupids"
  default     = "kube-system"
}

variable "aks_rbac_configmap" {
  type        = string
  description = "configmap where to store AKS Groupids"
  default     = "aks-rbac"
}

variable "jenkins_admin_sa" {
  type        = string
  description = "service account for Jenkins Admin"
  default     = "jenkins-admin"
}

variable "jenkins_deploy_sa" {
  type        = string
  description = "service account for Jenkins deployments"
  default     = "jenkins-deploy"
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
      enabled               = bool
      daemonset             = map(number)
      deployment            = map(number)
      hpa_max_replica       = map(number)
      restart_loop          = map(number)
      prometheus_disk_usage = map(number)
      prometheus_pod_memory = map(number)
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
      hpa_max_replica = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      restart_loop = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      prometheus_disk_usage = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 0
      }
      prometheus_pod_memory = {
        severity    = 3
        frequency   = 5
        time_window = 10
        threshold   = 75
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

variable "system_worker_agents_pool_name" {
  description = "The AKS worker agentpool (nodepool) name."
  type        = string
  default     = "sysagentpool"
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
    grafana_image_tag                            = string
    grafana_k8s_sidecar_image_tag                = string
    kube_state_metrics_image_tag                 = string
    node_exporter_image_tag                      = string
    prometheus_operator_image_tag                = string
    prometheus_config_reloader_image_tag         = string
    kube_webhook_certgen_image_tag               = string
    prometheus_replica                           = number
    prometheus_image_tag                         = string
    prometheus_retention                         = string
    prometheus_storage_class_name                = string
    prometheus_storage_size                      = string
    prometheus_drop_envoy_stats_for_context_pods = bool
    grafana_storage_class_name                   = string
    grafana_storage_size                         = string
  })
  default = {
    grafana_image_tag                            = "8.3.5"
    grafana_k8s_sidecar_image_tag                = "1.15.1"
    kube_state_metrics_image_tag                 = "v2.3.0"
    node_exporter_image_tag                      = "v1.3.1"
    prometheus_operator_image_tag                = "v0.54.0"
    prometheus_config_reloader_image_tag         = "v0.54.0"
    kube_webhook_certgen_image_tag               = "v1.0"
    prometheus_replica                           = 1
    prometheus_image_tag                         = "v2.33.1"
    prometheus_retention                         = "15d"
    prometheus_storage_class_name                = "managed-premium"
    prometheus_storage_size                      = "100Gi"
    prometheus_drop_envoy_stats_for_context_pods = false
    grafana_storage_class_name                   = "managed-premium"
    grafana_storage_size                         = "20Gi"
  }
}

variable "create_jenkins_namespace" {
  type        = bool
  description = "Create Jenkins Namespace for agents. Only needed on DEV cluster"
  default     = false
}

variable "enable_elk" {
  type        = bool
  description = "enable whether to log to elasticsearch or not "
  default     = true
}

variable "delete_validation_ns" {
  type        = bool
  description = "enable cronjob to delete validation ns"
  default     = false
}

variable "create_management_namespace" {
  type        = bool
  description = "Create Management Namespace for managing helm chart deployment on cluster"
  default     = true
}

variable "gatekeeper_config" {
  type = object({
    enable   = bool
    replicas = number
  })
  default = {
    enable   = false
    replicas = 3
  }
}
variable "enable_azure_service_operator" {
  type        = bool
  description = "enable azure service operator"
  default     = false
}

variable "enable_pgadmin" {
  type        = bool
  description = "enable pgadmin interface within cluster"
  default     = true
}

variable "azure_service_operator_tag" {
  type        = string
  description = "Azure Service Operator Docker image Tag"
  default     = "v2.3.0"
}

variable "kube_rbac_proxy_tag" {
  type        = string
  description = "Azure Service Operator KubeRbacProxy Docker image Tag"
  default     = "v0.13.1"
}

variable "azure_service_operator_crdpattern" {
  type        = string
  description = "Azure Service Operator crdPattern"
}

variable "pgadmin_tag" {
  type        = string
  description = "PGadmin Docker image Tag"
  default     = "6.14"
}

variable "pgadmin_admin_user" {
  type        = string
  description = "enable pgadmin interface within cluster"
  default     = "test@example.com"
}

variable "pgadmin_admin_password" {
  type        = string
  description = "enable pgadmin interface within cluster"
}

variable "pgadmin_oauth2_tenantid" {
  type        = string
  description = "pgadminoauth2_tenantId from app reg"
}
variable "pgadmin_oauth2_clientid" {
  type        = string
  description = "pgadmin_oauth2_clientid"
}
variable "pgadmin_oauth2_clientsecret" {
  type        = string
  description = "pgadmin_oauth2_clientSecret"
}

variable "pgadmin_postgres_rg" {
  type        = string
  description = "Resource Group where all postgres instances are, to look them up for pgadmin"
}

variable "pgadmin_hostnames" {
  type        = string
  description = "pgadmin hostname"
}

variable "pgadmin_port" {
  type        = string
  description = "pgadmin port"
}
variable "externaldb_host" {
  type        = string
  description = "pgadmin external DB host"
}
variable "externaldb_port" {
  type        = string
  description = "pgadmin external DB port"
}
variable "externaldb_name" {
  type        = string
  description = "pgadmin external DB name"
}
variable "externaldb_admin_user" {
  type        = string
  description = "external DB admin user"
}
variable "externaldb_admin_password" {
  type        = string
  description = "external DB admin password"
}
variable "pgadmin_shared_storage_path" {
  type        = string
  description = "pgadmin Shared storage path"
}
variable "pgadmin_restrict_storage_access" {
  type        = string
  description = "Enable or disable pgadmin shared storage restrictive permissions"
}

variable "istio_peer_authentication_mode" {
  type        = string
  default     = "STRICT"
  description = "This is istio mtls peer auth mode"
}

variable "istio_ingress_load_balancer_name" {
  type        = string
  default     = "kubernetes-internal"
  description = "Istio gateway LB name"
}
variable "addns" {
  type        = map(map(string))
  description = "ADDNS details"
  default = {
    nonlive = {
      domain    = "cpp.nonlive"
      resolvers = "192.168.88.4 192.168.88.5"
    }
    live = {
      domain    = "cp.cjs.hmcts.net"
      resolvers = "192.168.200.4 192.168.200.5"
    }
  }
}

variable "wait_for_k8s_api_to_be_available" {
  type        = map(any)
  description = "Used to wait k8s executions until the private endpoint and DNS is available"
}

variable "wait_for_acr_pe_to_be_available" {
  type        = string
  description = "Used to wait ACR PE to be available"
}

variable "enable_azure_pls_proxy_protocol" {
  type        = bool
  description = " TCP PROXY protocol should be enabled/disable on the PLS to pass through connection information, including the link ID and source IP address."
}

variable "src_ip_range" {
  type    = list(any)
  default = []
}

variable "velero_config" {
  type = object({
    enable                   = bool
    account_tier             = string
    account_replication_type = string
  })
  default = {
    enable                   = false
    account_tier             = "Standard"
    account_replication_type = "LRS"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "sonarqube_config" {
  type = object({
    enable         = bool
    jdbcUrl        = string
    sonarVaultPath = string
    sonarqubeUrl   = string
    hosts          = string
  })
  default = {
    enable         = false
    jdbcUrl        = ""
    sonarVaultPath = ""
    sonarqubeUrl   = ""
    hosts          = ""
  }
}

variable "keda_config" {
  type = object({
    enable           = bool
    image_tag        = string
    managed-identity = string
    tenant-id        = string
    replica_count    = string
    requests_mem     = string
    requests_cpu     = string
    limits_mem       = string
    limits_cpu       = string

  })
  default = {
    enable           = false
    image_tag        = "2.13.0"
    managed-identity = "52cd0539-fbf7-4e98-9b26-ee6cb4f89688" #from hcmts.net
    tenant-id        = "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
    replica_count    = "2"
    requests_mem     = "1000Mi"
    requests_cpu     = "1"
    limits_mem       = "2000Mi"
    limits_cpu       = "2"
  }
}


variable "ado-agents_config" {
  type = object({
    enable           = bool
    namespace        = string
    sa_name          = string
    azpurl           = string
    poolname         = string
    secretname       = string
    secretkey        = string
    managed-identity = string
    tenant-id        = string
    subscription-id  = string
    agents = list(object({
      agent_name                 = string
      image_name                 = string
      image_tag                  = string
      identifier                 = string
      requests_mem               = string
      requests_cpu               = string
      limits_mem                 = string
      limits_cpu                 = string
      scaled_min_job             = number
      scaled_max_job             = number
      pollinginterval            = number
      successfuljobshistorylimit = number
      failedjobshistorylimit     = number
      enable_istio_proxy         = bool
      init_container_config = list(object({
        container_name = string
        image_name     = string
        image_tag      = string
        requests_mem   = string
        requests_cpu   = string
        limits_mem     = string
        limits_cpu     = string
      }))
    }))
  })
  default = {
    enable           = false
    namespace        = "ado-agent"
    sa_name          = "ado-agent"
    azpurl           = "https://dev.azure.com/hmcts-cpp/"
    poolname         = "MDV-ADO-Agent-Aks"
    secretname       = "azdevops"
    secretkey        = "AZP_TOKEN"
    managed-identity = "52cd0539-fbf7-4e98-9b26-ee6cb4f89688" #from hcmts.net
    tenant-id        = "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
    subscription-id  = "ef8dd153-3fba-47a4-be65-15775bcde240"
    agents           = []
  }
}


variable "system_namespaces" {
  type        = list(string)
  description = "System component namespace list"
}

variable "enable_smashing" {
  type        = bool
  description = "enable smashing dashboards"
  default     = false
}

variable "smashing_image_tag" {
  type        = string
  description = "Image tag to use for smashing deployment"
  default     = "v1.3.8"
}

variable "smashing_scheduler_hmcts_dashboards_interval" {
  type        = string
  description = "How frequently the home dashboard should be updated"
  default     = "5m"
}

variable "smashing_scheduler_namespace_info_interval" {
  type        = string
  description = "How frequently environment info should be updated"
  default     = "5m"
}

variable "smashing_scheduler_suspend_stacks_refresh_interval" {
  type        = string
  description = "How frequently environment info should be updated"
  default     = "5m"
}

variable "smashing_idle_time_minutes" {
  type        = string
  description = "What is the idle time for environments"
  default     = "120"
}

variable "smashing_gateway_host_name" {
  type        = string
  description = "Hostname for istio gateway"
  default     = "smashing.mgmt01.dev.nl.cjscp.org.uk"
}

variable "enable_azure_keyvault" {
  description = "Enable writing Hashicorp Secret to AZ KV Secret"
  type        = bool
  default     = false
}

variable "keyvault_name" {
  description = "Name of Azure Keyvault"
  type        = string
  default     = ""
}

variable "keyvault_resource_group_name" {
  description = "Name of Azure Keyvault RG"
  type        = string
  default     = ""
}

variable "aso_resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = {
      cpu    = "1"
      memory = "3Gi"
    }
    limits = {
      cpu    = "2"
      memory = "4Gi"
    }
  }
}

variable "resource_types" {
  description = "List of Azure resource types for which to retrieve predefined roles"
  type        = list(string)
  default     = ["Key Vault Administrator", "Key Vault Contributor", "Storage Account Contributor", "Storage Blob Data Owner"]
}

variable "enable_azureinfo" {
  type        = bool
  description = "enable azure info details configmap"
  default     = true
}

variable "aks_cluster_set" {
  type        = string
  description = "AKS to pass cluster set example: cs01"
  default     = ""
}

variable "aks_cluster_number" {
  type        = string
  description = "AKS to pass cluster number example: cl01"
  default     = ""
}

variable "istiod_memory_request" {
  type        = string
  description = "memory for istiod pod"
  default     = "2Gi"
}

variable "istiod_cpu_request" {
  type        = string
  description = "cpu for istiod pod"
  default     = "500m"
}

variable "kiali_operator_replicas" {
  type        = string
  description = "no of kiali operator pods"
  default     = "1"
}

variable "kiali_cr_spec" {
  type = object({
    replica_count = number
    resources = object({
      requests = map(string)
      limits   = map(string)
    })
  })
}

variable "isito_ingress_spec" {
  type = object({
    resources = object({
      requests = map(string)
      limits   = map(string)
    })
  })
}

variable "kiali_operator_memory_request" {
  type        = string
  description = "memory for kiali operator pod"
  default     = "64Mi"
}

variable "kiali_operator_cpu_request" {
  type        = string
  description = "cpu for kiali operator pod"
  default     = "10m"
}

variable "smashing_spec" {
  type = object({
    resources = object({
      requests = map(string)
      limits   = map(string)
    })
  })
  default = {
    resources = {
      requests = {
        cpu    = "3000m"
        memory = "3Gi"
      }
      limits = {
        cpu    = "3000m"
        memory = "3Gi"
      }
    }
  }
}

variable "dynatrace_oneagent_version" {
  type        = string
  description = "dynatrace oneagent version"
  default     = "1.93.1000"
}

variable "dynatrace_operator_image_tag" {
  type        = string
  description = "dynatrace operator version"
  default     = "v1.3.0"
}

variable "istiod_hpa_cputarget" {
  type        = string
  description = "cpu target for istiod pod hpa"
  default     = "70"
}
