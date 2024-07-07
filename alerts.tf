data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

data "azurerm_monitor_action_group" "platformDev" {
  count               = var.alerts.enable_alerts ? 1 : 0
  name                = var.action_group_name
  resource_group_name = var.workspace_resource_group_name
}

data "azurerm_kubernetes_cluster_node_pool" "agentpool" {
  name                    = var.worker_agents_pool_name
  kubernetes_cluster_name = var.aks_cluster_name
  resource_group_name     = var.aks_resource_group_name
}

data "azurerm_kubernetes_cluster_node_pool" "sysagentpool" {
  name                    = var.system_worker_agents_pool_name
  kubernetes_cluster_name = var.aks_cluster_name
  resource_group_name     = var.aks_resource_group_name
}

resource "azurerm_monitor_metric_alert" "aks_infra_alert_cpu_usage" {
  count               = var.alerts.enable_alerts && var.alerts.infra.enabled ? 1 : 0
  name                = "aks_cpu_usage_greater_than_percent"
  resource_group_name = var.aks_resource_group_name
  scopes              = [data.azurerm_kubernetes_cluster.cluster.id]
  description         = "Action will be triggered when cpu usage is greater than 80%"
  enabled             = var.alerts.infra.enabled

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alerts.infra.cpu_usage_threshold
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.platformDev.0.id
  }
}

resource "azurerm_monitor_metric_alert" "aks_infra_alert_disk_usage" {
  count               = var.alerts.enable_alerts && var.alerts.infra.enabled ? 1 : 0
  name                = "aks_disk_usage_greater_than_percent"
  resource_group_name = var.aks_resource_group_name
  scopes              = [data.azurerm_kubernetes_cluster.cluster.id]
  description         = "Action will be triggered when disk usage is greater than 80%"
  enabled             = var.alerts.infra.enabled

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_disk_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alerts.infra.disk_usage_threshold
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.platformDev.0.id
  }
}

resource "azurerm_monitor_metric_alert" "aks_infra_alert_node_limit" {
  count               = var.alerts.enable_alerts && var.alerts.infra.enabled ? 1 : 0
  name                = "aks_node_count_not_in_ready_state"
  resource_group_name = var.aks_resource_group_name
  scopes              = [data.azurerm_kubernetes_cluster.cluster.id]
  description         = "Action will be triggered when node count is notready state is greater than 0"
  enabled             = var.alerts.infra.enabled

  criteria {
    metric_namespace = "insights.container/nodes"
    metric_name      = "nodesCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alerts.infra.node_limit_threshold

    dimension {
      name     = "status"
      operator = "Include"
      values   = ["NotReady"]
    }
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.platformDev.0.id
  }
}

resource "azurerm_monitor_metric_alert" "aks_infra_alert_cluster_health" {
  count               = var.alerts.enable_alerts && var.alerts.infra.enabled ? 1 : 0
  name                = "aks_cluster_health"
  resource_group_name = var.aks_resource_group_name
  scopes              = [data.azurerm_kubernetes_cluster.cluster.id]
  description         = "Action will be triggered when clsuter health is bad"
  enabled             = var.alerts.infra.enabled

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "cluster_autoscaler_cluster_safe_to_autoscale"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = var.alerts.infra.cluster_health_threshold
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.platformDev.0.id
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_sys_alert_daemonset_statefulset" {
  count               = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
  name                = "aks_sys_alert_daemonset_statefulset"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when sys daemonsets or statefulsets are not healthy"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  KubePodInventory
    | where ControllerKind has "daemonset" or  ControllerKind has "statefulset"
    | where Namespace !contains "ccm"
    | where PodStatus has "Failed" or PodStatus has "Unknown"
QUERY
  severity                = var.alerts.sys_workload.daemonset.severity
  frequency               = var.alerts.sys_workload.daemonset.frequency
  time_window             = var.alerts.sys_workload.daemonset.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.daemonset.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_sys_alert_actual_vs_desired_replica" {
  count               = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
  name                = "aks_sys_actual_vs_desired_replica_of_pods"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when actual replica of pods is less than desired replcia"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  InsightsMetrics
    | where Name has "kube_deployment_status_replicas_ready"
    | extend tags=parse_json(Tags)
    | where tags.k8sNamespace !contains "ccm"
    | where toint(tags.status_replicas_available) < toint(tags.spec_replicas)
    | distinct tostring(tags.deployment),tostring(tags.k8sNamespace)
QUERY
  severity                = var.alerts.sys_workload.deployment.severity
  frequency               = var.alerts.sys_workload.deployment.frequency
  time_window             = var.alerts.sys_workload.deployment.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.deployment.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_apps_alert_actual_vs_desired_replica" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_apps_actual_vs_desired_replica_of_pods"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when actual replica of pods is less than desired replcia"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  InsightsMetrics
    | where Name has "kube_deployment_status_replicas_ready"
    | extend tags=parse_json(Tags)
    | where tags.k8sNamespace contains "ccm"
    | where toint(tags.status_replicas_available) < toint(tags.spec_replicas)
    | distinct tostring(tags.deployment),tostring(tags.k8sNamespace)
QUERY
  severity                = var.alerts.apps_workload.deployment.severity
  frequency               = var.alerts.apps_workload.deployment.frequency
  time_window             = var.alerts.apps_workload.deployment.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.deployment.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_apps_hpa_desired_replica_less_than_min_replica" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_apps_hpa_desired_replica_less_than_min_replica"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when actual replica of pods is less than minimum replicas of hpa"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  InsightsMetrics
    | where Name has "kube_hpa_status_current_replicas"
    | extend tags=parse_json(Tags)
    | where tags.k8sNamespace contains "ccm"
    | where toint(tags.status_desired_replicas) < toint(tags.spec_min_replicas)
    | distinct tostring(tags.hpa),tostring(tags.k8sNamespace)
QUERY
  severity                = var.alerts.apps_workload.hpa_min_replica.severity
  frequency               = var.alerts.apps_workload.hpa_min_replica.frequency
  time_window             = var.alerts.apps_workload.hpa_min_replica.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.hpa_min_replica.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_apps_hpa_desired_replica_equal_to_max_replica" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_apps_hpa_desired_replica_equal_to_max_replica"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when actual replica of pods is equal to maximum replicas of hpa"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  InsightsMetrics
    | where Name has "kube_hpa_status_current_replicas"
    | extend tags=parse_json(Tags)
    | where tags.k8sNamespace contains "ccm"
    | where toint(tags.status_desired_replicas) == toint(tags.spec_max_replicas)
    | distinct tostring(tags.hpa),tostring(tags.k8sNamespace)
QUERY
  severity                = var.alerts.apps_workload.hpa_max_replica.severity
  frequency               = var.alerts.apps_workload.hpa_max_replica.frequency
  time_window             = var.alerts.apps_workload.hpa_max_replica.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.hpa_max_replica.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_worker_agent_pool_count_status" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_worker_agent_pool_count_status"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when worker node pool is reached max threshold value"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  let nodepoolMaxnodeCount = ${data.azurerm_kubernetes_cluster_node_pool.agentpool.max_count};
  let _minthreshold = 70;
  KubeNodeInventory
    | extend nodepoolType = todynamic(Labels)
    | extend nodepoolName = todynamic(nodepoolType[0].agentpool)
    | where nodepoolName contains "${data.azurerm_kubernetes_cluster_node_pool.agentpool.name}"
    | extend nodepoolName = tostring(nodepoolName)
    | summarize nodeCount = count(Computer) by ClusterName, tostring(nodepoolName), TimeGenerated
    | extend scaledpercent = iff(((nodeCount * 100 / nodepoolMaxnodeCount) >= _minthreshold), "warn", "normal")
    | where scaledpercent == 'warn'
    | summarize arg_max(TimeGenerated, *) by nodeCount, ClusterName, tostring(nodepoolName)
    | project ClusterName,
        TotalNodeCount= strcat("Total Node Count: ", nodeCount),
        ScaledOutPercentage = (nodeCount * 100 / nodepoolMaxnodeCount),
        TimeGenerated,
        nodepoolName, scaledpercent
QUERY
  severity                = var.alerts.apps_workload.cluster_agent_pool.severity
  frequency               = var.alerts.apps_workload.cluster_agent_pool.frequency
  time_window             = var.alerts.apps_workload.cluster_agent_pool.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.cluster_agent_pool.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_system_agent_pool_count_status" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_system_agent_pool_count_status"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when system node pool is reached max threshold value"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  let nodepoolMaxnodeCount = ${data.azurerm_kubernetes_cluster_node_pool.sysagentpool.max_count};
  let _minthreshold = 70;
  KubeNodeInventory
    | extend nodepoolType = todynamic(Labels)
    | extend nodepoolName = todynamic(nodepoolType[0].agentpool)
    | where nodepoolName contains "${data.azurerm_kubernetes_cluster_node_pool.sysagentpool.name}"
    | extend nodepoolName = tostring(nodepoolName)
    | summarize nodeCount = count(Computer) by ClusterName, tostring(nodepoolName), TimeGenerated
    | extend scaledpercent = iff(((nodeCount * 100 / nodepoolMaxnodeCount) >= _minthreshold), "warn", "normal")
    | where scaledpercent == 'warn'
    | summarize arg_max(TimeGenerated, *) by nodeCount, ClusterName, tostring(nodepoolName)
    | project ClusterName,
        TotalNodeCount= strcat("Total Node Count: ", nodeCount),
        ScaledOutPercentage = (nodeCount * 100 / nodepoolMaxnodeCount),
        TimeGenerated,
        nodepoolName, scaledpercent
QUERY
  severity                = var.alerts.apps_workload.cluster_agent_pool.severity
  frequency               = var.alerts.apps_workload.cluster_agent_pool.frequency
  time_window             = var.alerts.apps_workload.cluster_agent_pool.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.cluster_agent_pool.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_all_pod_status" {
  count               = var.alerts.enable_alerts && var.alerts.apps_workload.enabled ? 1 : 0
  name                = "aks_all_pod_status"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when any namespace pod is unhealthy"
  enabled                 = var.alerts.apps_workload.enabled
  query                   = <<-QUERY
  KubeEvents
    | where Reason contains "Unhealthy"
    | distinct tostring(Namespace), tostring(ClusterName), tostring(Name)
QUERY
  severity                = var.alerts.apps_workload.cluster_agent_pool.severity
  frequency               = var.alerts.apps_workload.cluster_agent_pool.frequency
  time_window             = var.alerts.apps_workload.cluster_agent_pool.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.apps_workload.cluster_agent_pool.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "prometheus_pod_memory_usage" {
  count               = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
  name                = "prometheus_pod_memory_usage_status"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when Prometheus pod memory usage is above 75% usage memory"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  let endDateTime = now();
  let startDateTime = ago(1h);
  let trendBinSize = 1m;
  let capacityCounterName = 'memoryLimitBytes';
  let usageCounterName = 'memoryRssBytes';
  let clusterName = '${data.azurerm_kubernetes_cluster.cluster.name}';
  let controllerName = 'prometheus-kube-prometheus-stack-prometheus';
  KubePodInventory
    | where TimeGenerated < endDateTime
    | where TimeGenerated >= startDateTime
    | where ClusterName == clusterName
    | where ControllerName == controllerName
    | extend InstanceName = strcat(ClusterId, '/', ContainerName),
             ContainerName = strcat(controllerName, '/', tostring(split(ContainerName, '/')[1]))
    | distinct Computer, InstanceName, ContainerName
    | join hint.strategy=shuffle (
        Perf
        | where TimeGenerated < endDateTime
        | where TimeGenerated >= startDateTime
        | where ObjectName == 'K8SContainer'
        | where CounterName == capacityCounterName
        | summarize LimitValue = max(CounterValue) by Computer, InstanceName, bin(TimeGenerated, trendBinSize)
        | project Computer, InstanceName, LimitStartTime = TimeGenerated, LimitEndTime = TimeGenerated + trendBinSize, LimitValue
    ) on Computer, InstanceName
    | join kind=inner hint.strategy=shuffle (
        Perf
        | where TimeGenerated < endDateTime + trendBinSize
        | where TimeGenerated >= startDateTime - trendBinSize
        | where ObjectName == 'K8SContainer'
        | where CounterName == usageCounterName
        | project Computer, InstanceName, UsageValue = CounterValue, TimeGenerated
    ) on Computer, InstanceName
    | where TimeGenerated >= LimitStartTime and TimeGenerated < LimitEndTime
    | project Computer, ContainerName, TimeGenerated, UsagePercent = UsageValue * 100.0 / LimitValue
    | summarize AggregatedValue = avg(UsagePercent) by bin(TimeGenerated, trendBinSize) , ContainerName
QUERY
  severity                = var.alerts.sys_workload.prometheus_pod_memory.severity
  frequency               = var.alerts.sys_workload.prometheus_pod_memory.frequency
  time_window             = var.alerts.sys_workload.prometheus_pod_memory.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.prometheus_pod_memory.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "prometheus_node_disk_usage_status" {
  count               = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
  name                = "prometheus_node_disk_usage_status"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when Prometheus node disk usage is reached to 75% usage disk"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  let setGBValue = 120;
  InsightsMetrics
    | where TimeGenerated > ago(1h)
    | where Name contains "pvUsedBytes"
    | extend tags=parse_json(Tags)
    | where tags.pvcNamespace contains "prometheus"
    | project Val, tags.pvCapacityBytes, _SubscriptionId, _ResourceId
    | extend UsedDiskGB = Val/1000000000
    | extend TotalDiskSpaceGB = tags_pvCapacityBytes/1000000000
    | summarize FreespaceGB = min(UsedDiskGB) by _ResourceId,  _SubscriptionId
    | where FreespaceGB >= setGBValue
QUERY
  severity                = var.alerts.sys_workload.prometheus_disk_usage.severity
  frequency               = var.alerts.sys_workload.prometheus_disk_usage.frequency
  time_window             = var.alerts.sys_workload.prometheus_disk_usage.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.prometheus_disk_usage.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_sys_hpa_desired_replica_close_to_max_replica" {
  count               = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
  name                = "aks_sys_hpa_desired_replica_close_to_max_replica"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when actual replica of pods is close to maximum replicas of hpa"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  let _minthreshold = 80;
  InsightsMetrics
    | where Name has "kube_hpa_status_current_replicas"
    | extend tags=parse_json(Tags)
    | where tags.k8sNamespace !contains "ccm"
    | where toint(tags.status_desired_replicas) >= toint(tags.spec_max_replicas) * (_minthreshold / 100.0)
    | distinct tostring(tags.hpa),tostring(tags.k8sNamespace)
QUERY
  severity                = var.alerts.sys_workload.hpa_max_replica.severity
  frequency               = var.alerts.sys_workload.hpa_max_replica.frequency
  time_window             = var.alerts.sys_workload.hpa_max_replica.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.hpa_max_replica.threshold
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "aks_sys_pod_restart_loop_alert" {
  count = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0

  name                = "aks_sys_pod_restart_loop_alert"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when a pod is in a restart loop in sys namespaces"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  KubeEvents
  | where Reason == "BackOff"
  | summarize EventCount = count() by Name, Namespace, Computer
  | where EventCount >= 5
  | project Name, Namespace, Computer, EventCount
QUERY
  severity                = var.alerts.sys_workload.restart_loop.severity
  frequency               = var.alerts.sys_workload.restart_loop.frequency
  time_window             = var.alerts.sys_workload.restart_loop.time_window
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.restart_loop.threshold
  }
}





resource "azurerm_monitor_scheduled_query_rules_alert" "test_pod_fail_alert" {
  count = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0

  name                = "test-pod-failure-alert"
  location            = var.aks_cluster_location
  resource_group_name = var.aks_resource_group_name

  action {
    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
  }
  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
  description             = "Alert when a pod startin with test in default ns fails"
  enabled                 = var.alerts.sys_workload.enabled
  query                   = <<-QUERY
  KubeEvents
  | where Namespace == "default"
  | where Name startswith "test-pod"
  | where Reason == "Failed"
  | project TimeGenerated, Name, Reason, Message
QUERY
  severity                = var.alerts.sys_workload.restart_loop.severity
  frequency               = 5
  time_window             = 5
  auto_mitigation_enabled = true
  trigger {
    operator  = "GreaterThan"
    threshold = var.alerts.sys_workload.restart_loop.threshold
  }
}


#resource "azurerm_monitor_scheduled_query_rules_alert" "test__alert" {
#  count = var.alerts.enable_alerts && var.alerts.sys_workload.enabled ? 1 : 0
#
#  name                = "test-alert"
#  location            = var.aks_cluster_location
#  resource_group_name = var.aks_resource_group_name
#
#  action {
#    action_group = [data.azurerm_monitor_action_group.platformDev.0.id]
#  }
#  data_source_id          = data.azurerm_kubernetes_cluster.cluster.id
#  description             = "Alert when last digit of min less than 5 "
#  enabled                 = var.alerts.sys_workload.enabled
#  query                   = <<-QUERY
#  let CurrentMinute = toint(format_datetime(now(), 'mm'));
#  let LastDigit = CurrentMinute % 10;
#  LastDigit < 5
#QUERY
#  severity                = var.alerts.sys_workload.restart_loop.severity
#  frequency               = 5
#  time_window             = 5
#  auto_mitigation_enabled = true
#  trigger {
#    operator  = "GreaterThan"
#    threshold = var.alerts.sys_workload.restart_loop.threshold
#  }
#}
#
#
