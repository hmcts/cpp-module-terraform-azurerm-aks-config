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