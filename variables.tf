variable "istio_version" {
  default     = "1.10.2"
  description = "The version of Istio to be installed"
  type        = string
}

variable "istio_node_selector_label" {
  description = "Node selector label to install istio on selected nodes"
  type        = string
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

variable "jenkins_rbac_chart_name" {
  type        = string
  description = "Name of the chart for jenkins-rbac"
}

variable "jenkins_rbac_chart_path" {
  type        = string
  description = "Path in the ACR for the chart"
}

variable "jenkins_rbac_chart_version" {
  type        = string
  description = "Version of the chart"
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
