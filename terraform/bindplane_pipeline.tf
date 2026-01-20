provider "bindplane" {
  remote_url = "http://${google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip}:3001"
  api_key    = var.bindplane_api_key
}

resource "bindplane_source" "journald" {
  name    = "journald-${random_id.suffix.hex}"
  type    = "journald"
  rollout = true
}

resource "bindplane_processor" "batch" {
  name    = "batch-${random_id.suffix.hex}"
  type    = "batch"
  rollout = true
}

resource "bindplane_configuration" "logs" {
  name     = "vm-logs-${random_id.suffix.hex}"
  platform = "linux"
  rollout  = true

  source {
    name       = bindplane_source.journald.name
    processors = [bindplane_processor.batch.name]
  }

  destination {
    name = "googlecloud"
  }

  destination {
    name = "googlebucket"
  }
}
