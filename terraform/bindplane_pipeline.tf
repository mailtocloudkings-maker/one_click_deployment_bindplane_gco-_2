################################
# Auto-generate BindPlane API Key
################################
resource "null_resource" "bindplane_api_key" {
  depends_on = [null_resource.install_bindplane_agent]

  provisioner "local-exec" {
    command = <<EOT
SERVER_IP=$(terraform output -raw bindplane_vm_ip)

# Login to BindPlane UI and get session token
TOKEN=$(curl -s -X POST http://$SERVER_IP:3001/v1/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password*test"}' | jq -r '.token')

# Create API key
API_KEY=$(curl -s -X POST http://$SERVER_IP:3001/v1/api-keys \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"terraform-key"}' | jq -r '.key')

# Save to bindplane.auto.tfvars for Terraform provider
echo "bindplane_api_key=\"$API_KEY\"" > bindplane.auto.tfvars
EOT
  }
}

################################
# BindPlane Provider
################################
provider "bindplane" {
  remote_url = "http://${google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip}:3001"
  # api_key will be read automatically from bindplane.auto.tfvars
}

################################
# SOURCES
################################
resource "bindplane_source" "host_metrics" {
  rollout = true
  name    = "host-metrics-${random_id.suffix.hex}"
  type    = "host"

  parameters_json = jsonencode([
    { name = "collection_interval", value = 60 },
    { name = "enable_process", value = true }
  ])
}

resource "bindplane_source" "journald_logs" {
  rollout = true
  name    = "journald-logs-${random_id.suffix.hex}"
  type    = "journald"
}

################################
# PROCESSOR
################################
resource "bindplane_processor" "batch" {
  rollout = true
  name    = "batch-${random_id.suffix.hex}"
  type    = "batch"

  parameters_json = jsonencode([
    { name = "send_batch_size", value = 200 },
    { name = "send_batch_max_size", value = 400 },
    { name = "timeout", value = "5s" }
  ])
}

################################
# CONFIGURATIONS
################################
resource "bindplane_configuration" "logs_config" {
  rollout  = true
  name     = "agent-vm-logs-${random_id.suffix.hex}"
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
    name = "googlebucket" # GCS bucket destination
  }
}

resource "bindplane_configuration" "metrics_config" {
  rollout  = true
  name     = "agent-vm-metrics-${random_id.suffix.hex}"
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
    name = "googlebucket" # GCS bucket destination
  }
}
