resource "kubernetes_namespace" "flux_system_namespace" {
  count = var.flux_config.enable ? 1 : 0
  metadata {
    name = "flux-system"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubernetes_secret" "flux_github_app" {
  count = var.flux_config.enable ? 1 : 0
  metadata {
    name      = "flux-github-app-secret"
    namespace = kubernetes_namespace.flux_system_namespace[0].metadata.0.name
  }

  data = {
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = data.vault_generic_secret.githubappkey_cred.0.data["value"]
  }

  type = "Opaque"
}

resource "helm_release" "flux_operator" {
  count      = var.flux_config.enable ? 1 : 0
  name       = lookup(var.charts.flux-operator, "name", "flux-operator")
  chart      = lookup(var.charts.flux-operator, "name", "flux-operator")
  version    = lookup(var.charts.flux-operator, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.flux_system_namespace[0].metadata.0.name

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.download_charts,
    kubernetes_namespace.flux_system_namespace
  ]
}

resource "helm_release" "flux_instance" {
  count      = var.flux_config.enable ? 1 : 0
  depends_on = [helm_release.flux_operator]

  name       = lookup(var.charts.flux-instance, "name", "flux-instance")
  chart      = lookup(var.charts.flux-instance, "name", "flux-instance")
  version    = lookup(var.charts.flux-instance, "version", "")
  repository = "./install"
  namespace  = kubernetes_namespace.flux_system_namespace[0].metadata.0.name
  wait       = true
  timeout    = 300

  // Configure the Flux components and kustomize patches.
  values = [
    templatefile("${path.module}/manifests/flux-instance-value/components.yaml", {
      client_id = var.aks_worker_client_id
    })
  ]

  // Configure the Flux distribution, cluster type and Git sync.

  set {
    name  = "instance.distribution.version"
    value = var.flux_version
  }
  set {
    name  = "instance.distribution.registry"
    value = var.flux_registry
  }
  set {
    name  = "instance.cluster.type"
    value = var.cluster_type
  }
  set {
    name  = "instance.cluster.size"
    value = var.cluster_size
  }
  set {
    name  = "instance.sync.kind"
    value = "GitRepository"
  }
  set {
    name  = "instance.sync.url"
    value = var.git_url
  }
  set {
    name  = "instance.sync.path"
    value = var.git_path
  }
  set {
    name  = "instance.sync.ref"
    value = var.git_ref
  }
  set {
    name  = "instance.sync.provider"
    value = "github"
  }
  set {
    name  = "instance.sync.pullSecret"
    value = "flux-github-app-secret"
  }
  set {
    name  = "healthcheck.enabled"
    value = "true"
    type  = "auto"
  }

}
