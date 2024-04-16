# Need to improve auth to ACR. The helm provider v2 should be able to do it but cannot get it to working. Need to revisit.
# https://stackoverflow.com/questions/59565463/deploying-helm-charts-via-terraform-helm-provider-and-azure-devops-while-fetchin
resource "null_resource" "download_charts" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!bash -x
      export HELM_EXPERIMENTAL_OCI=1
      HELM_BINARY=$${HELM_BINARY:-helm}
      $$HELM_BINARY registry login ${var.acr_name}.azurecr.io --username ${var.acr_user_name} --password ${var.acr_user_password}
      %{for chart in var.charts}
      if [ "$$HELM_BINARY" = "helm-3.14.2" ]; then
        if [ -d "./install/$$(basename ${chart.path})" ]; then
          rm -rf "./install/$$(basename ${chart.path})"
        fi
        mkdir -p ./install
        $$HELM_BINARY pull oci://${var.acr_name}.azurecr.io/${chart.path} --version ${chart.version} --destination ./install
        tar zxvf ./install/$$(basename ${chart.path})-${chart.version}.tgz -C ./install
        rm -f ./install/$$(basename ${chart.path})-${chart.version}.tgz
      else
        $$HELM_BINARY chart remove ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
        $$HELM_BINARY chart pull ${var.acr_name}.azurecr.io/${chart.path}:${chart.version}
        $$HELM_BINARY chart export ${var.acr_name}.azurecr.io/${chart.path}:${chart.version} --destination ./install
      fi
      %{endfor~}
    EOT
  }
}
