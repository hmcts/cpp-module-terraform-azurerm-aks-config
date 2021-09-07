variable "istio_version" {
  default     = "1.10.2"
  description = "The version of Istio to be installed"
  type        = string
}

variable "istio_node_selector_label" {
  description = "Node selector label to install istio on selected nodes"
  type        = string
}

variable "systempool_taint_key" {
  description = "system pool taint key"
  type        = string
  default     = "CriticalAddonsOnly"
}

variable "systempool_taint_value" {
  description = "system pool taint value"
  type        = bool
  default     = true
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

variable "ingressdomain" {
  type        = string
  description = "Ingress domain name FQDN"
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

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name"
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

variable "istio_gateway_cert_secret_name" {
  type    = string
  default = "istio-ingressgateway-certs"
}

variable "istio_components_hpa_spec" {
  type    = map(number)
  default = {
    min_replicas = 1
    max_replicas = 5
  }
}

variable "dynatrace_components_hpa_spec" {
  type = map(number)
  default = {
    min_replicas = 1
    max_replicas = 2
    avg_cpu_utilization = 80
    avg_mem_utilization = 80
  }
}


variable "charts" {
  type = object({
    namespace = map(string)
    jenkins-rbac = map(string)
    istio-operator = map(string)
  })
  default = {
    namespace = {
      path = "charts/namespace"
      version = "0.1.0"
    },
    jenkins-rbac = {
      path = "charts/jenkins-rbac"
      version = "1.0.1"
    },
    istio-operator = {
      path = "charts/istio-operator"
      version = "1.10.2"
    }    
  }
}