# Idea behind this plugin

Every Marathon's app is divided into tasks. Tasks are spawned on slave machines by some master.
Procedure:
1. Download apps list from marathon
2. For each app get its details from marathon (v2/apps/<app_id> rest endpoint)
3. For each task in app:
  1. Get slave address from task's description.
  2. Get task details/metrics from mesos using its slave address and its mesos rest endpoint.
  3. Get slave (for whole machine) details/metrics from mesos.
  4. Publish task/container metrics and slave/task percentage metrics (find a way of merging these metrics).
