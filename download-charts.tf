locals {
  chart_values = yamldecode(file("${path.root}/chart-values/${var.environment}.yaml"))
}

# Need to improve auth to ACR. The helm provider v2 should be able to do it but cannot get it to working. Need to revisit.
# https://stackoverflow.com/questions/59565463/deploying-helm-charts-via-terraform-helm-provider-and-azure-devops-while-fetchin
resource "null_resource" "download_charts" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      export HELM_EXPERIMENTAL_OCI=1
      helm registry login ${var.acr_name}.azurecr.io --username ${var.acr_user_name} --password ${var.acr_user_password}
      %{ for chart in var.charts }
      helm chart remove ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
      helm chart pull ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
      helm chart export ${var.acr_name}.azurecr.io/${chart.path}:${chart.version} --destination ./install
      %{ endfor ~}
    EOT
  }
}