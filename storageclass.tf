resource "kubectl_manifest" "custom_storageclass_file_alfresco" {
  yaml_body = <<YAML
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile-csi-alfresco-retain
provisioner: file.csi.azure.com
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict
  - actimeo=30
parameters:
  skuName: Standard_LRS
reclaimPolicy: Retain
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}

resource "kubectl_manifest" "custom_storageclass_disk_alfresco" {
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-premium-alfresco
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_LRS
  maxShares: "2"
  cachingMode: None
reclaimPolicy: Delete
YAML
  lifecycle {
    ignore_changes = [field_manager]
  }
  depends_on = [time_sleep.wait_for_aks_api_dns_propagation]
}
