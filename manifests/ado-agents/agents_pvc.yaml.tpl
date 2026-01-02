apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${pvc_name}
  namespace: ${namespace}
  labels:
    environment: ${environment}
    cluster: ${aks_cluster_name}
spec:
  accessModes:
    - ${access_mode}
  resources:
    requests:
      storage: ${storage_size}
  storageClassName: ${storage_class}
