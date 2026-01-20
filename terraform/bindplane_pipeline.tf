################################
# BindPlane Provider
################################
provider "bindplane" {
  remote_url = "http://${google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip}:3001"
  api_key    = var.bindplane_api_key
}

################################
# SOURCES
################################
resource "bindplane_source" "host_metrics" {
  rollout = true
  name    = "host-metrics-${random_id.suffix.hex}"
  type    = "host"

  parameters_json = jsonencode([
    {
      name  = "collection_interval"
      value = 60
    },
    {
      name  = "enable_process"
      value = true
    }
  ])
}

resource "bindplane_source" "journald_logs" {
  rollout = true
  name    = "journald-logs-${random_id.suffix.hex}"
  type    = "journald"
}

################################
# PROCESSORS
################################
resource "bindplane_processor" "batch" {
  rollout = true
  name    = "batch-${random_id.suffix.hex}"
  type    = "batch"

  parameters_json = jsonencode([
    {
      name  = "send_batch_size"
      value = 200
    },
    {
      name  = "send_batch_max_size"
      value = 400
    },
    {
      name  = "timeout"
      value = "5s"
    }
  ])
}

################################
# LOGS CONFIGURATION
################################
resource "bindplane_configuration" "logs_config" {
  rollout  = true
  name     = "vm-logs-${random_id.suffix.hex}"
  platform = "linux"

  labels = {
    environment = "development"
    managed_by  = "terraform"
  }

  source {
    name       = bindplane_source.journald_logs.name
    processors = [bindplane_processor.batch.name]
  }

  destination {
    name = "googlebucket"
  }
}

################################
# METRICS CONFIGURATION
################################
resource "bindplane_configuration" "metrics_config" {
  rollout  = true
  name     = "vm-metrics-${random_id.suffix.hex}"
  platform = "linux"

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }

  source {
    name       = bindplane_source.host_metrics.name
    processors = [bindplane_processor.batch.name]
  }

  destination {
    name = "googlebucket"
  }
}
