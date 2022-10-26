---
apiVersion: v1
kind: Config
clusters:
  - name: ${cluster_name}
    cluster:
      certificate-authority-data: ${ca_data}
      server: ${server}
contexts:
  - name: ${service_account}@${cluster_name}
    context:
      cluster: ${cluster_name}
      namespace: ${namespace}
      user: ${service_account}
users:
  - name: ${service_account}
    user:
      token: ${token}
current-context: ${service_account}@${cluster_name}
