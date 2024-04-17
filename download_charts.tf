# Need to improve auth to ACR. The helm provider v2 should be able to do it but cannot get it to working. Need to revisit.
# https://stackoverflow.com/questions/59565463/deploying-helm-charts-via-terraform-helm-provider-and-azure-devops-while-fetchin

locals {
  charts_info = [for chart in var.charts : {
    path       = chart.path
    version    = chart.version
    dir        = "install/${element(split("/", chart.path), 1)}"
    chart_name = "${element(split("/", chart.path), 1)}"
  }]
  helm_binary = "$HELM_BINARY"
}

resource "null_resource" "download_charts" {
  triggers = {
    always_run = "${timestamp()}"
  }


  provisioner "local-exec" {
    command = <<-EOT
      #!bash -x
      export HELM_EXPERIMENTAL_OCI=1
      HELM_BINARY=$${HELM_BINARY:-helm}
      ${local.helm_binary} registry login ${var.acr_name}.azurecr.io --username ${var.acr_user_name} --password ${var.acr_user_password}
      mkdir -p ./install
      %{for chart in local.charts_info~}
      if [ ${local.helm_binary} = "helm-3.14.2" ]; then
        if [ -d "${chart.dir}" ]; then
          rm -rf "${chart.dir}"
        fi
        ${local.helm_binary} pull oci://${var.acr_name}.azurecr.io/${chart.path} --version ${chart.version} --destination ./install
        tar zxvf ${chart.dir}-${chart.version}.tgz -C install
        rm -f ${chart.dir}-${chart.version}.tgz
      else
        ${local.helm_binary} chart remove ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
        ${local.helm_binary} chart pull ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
        ${local.helm_binary} chart export ${var.acr_name}.azurecr.io/${chart.path}:${chart.version} --destination ./install
      fi
      %{endfor~}
    EOT
  }
}
