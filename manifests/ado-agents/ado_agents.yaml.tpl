---
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: ${environment}-${aks_cluster_set}-${aks_cluster_number}-${agent_name}
  namespace: ${namespace}
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
  triggers:
    - type: azure-pipelines
      metadata:
        poolName: ${poolname}
        organizationURLFromEnv: "AZP_URL"
        demands: "identifier -equals ${identifier}"
      authenticationRef:
        name: pipeline-trigger-auth
  jobTargetRef:
    template:
      metadata:
        labels:
          azure.workload.identity/use: "true"
          sidecar.istio.io/inject: "${enable_istio_proxy}"
        annotations:
          proxy.istio.io/config: '{ "holdApplicationUntilProxyStarts": ${enable_istio_proxy} }'
      spec:
        serviceAccountName: ${sa_name}
        restartPolicy: Never
        containers:
          - name: azdevops-agent
            securityContext:
              runAsNonRoot: true
              runAsUser: 1000
            image: ${acr_name}.azurecr.io/hmcts/${image_name}:${image_tag}
            imagePullPolicy: Always
            env:
              - name: AZP_URL
                value: ${azpurl}
              - name: AZP_POOL
                value: ${poolname}
              - name: AZURE_TENANT_ID
                value: ${tenant_id}
              - name: AZURE_SUBSCRIPTION_ID
                value: ${subscription_id}
              - name: identifier
                value: ${identifier}
              - name: CLUSTER
                value: ${aks_cluster_name}
              - name: LC_ALL
                value: en_GB.UTF-8
              - name: LANG
                value: en_GB.UTF-8
              - name: LANGUAGE
                value: en_GB.UTF-8
            resources:
              limits:
                cpu: "${limits_cpu}"
                memory: ${limits_mem}
              requests:
                cpu: "${requests_cpu}"
                memory: ${requests_mem}
        %{ if length(jsondecode(init_containers)) > 0 }
        initContainers:
          %{ for init_container in jsondecode(init_containers) }
          - name: ${init_container.container_name}
            image: ${acr_name}.azurecr.io/hmcts/${init_container.image_name}:${init_container.image_tag}
            securityContext:
              runAsNonRoot: true
              runAsUser: 1000
            imagePullPolicy: Always
            restartPolicy: Always
            env:
              - name: ALLOW_EMPTY_PASSWORD
                value: "yes"
              - name: POSTGRESQL_EXTRA_FLAGS
                value: -c max_prepared_transactions=100
            resources:
              limits:
                cpu: "${init_container.limits_cpu}"
                memory: ${init_container.limits_mem}
              requests:
                cpu: "${init_container.requests_cpu}"
                memory: ${init_container.requests_mem}
          %{ endfor }
        %{ endif }
  pollingInterval: ${pollinginterval}
  successfulJobsHistoryLimit: ${successfuljobshistorylimit}
  failedJobsHistoryLimit: ${failedjobshistorylimit}
  minReplicaCount: ${scaled_min_job}
  maxReplicaCount: ${scaled_max_job}
  rollout:
    strategy: gradual
