################################
# Generate API key automatically
################################
resource "null_resource" "bindplane_api_key" {
  depends_on = [null_resource.install_bindplane_agent]

  provisioner "local-exec" {
    command = <<EOT
SERVER_IP=$(terraform output -raw bindplane_vm_ip)

TOKEN=$(curl -s -X POST http://$SERVER_IP:3001/v1/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password*test"}' | jq -r '.token')

API_KEY=$(curl -s -X POST http://$SERVER_IP:3001/v1/api-keys \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"terraform-key"}' | jq -r '.key')

echo "bindplane_api_key=\"$API_KEY\"" > bindplane.auto.tfvars
EOT
  }
}

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
resource "bindplane_source" "journald_logs" {
  rollout = true
  name    = "journald-${random_id.suffix.hex}"
  type    = "journald"
}

################################
# PROCESSOR
################################
resource "bindplane_processor" "batch" {
  rollout = true
  name    = "batch-${random_id.suffix.hex}"
  type    = "batch"
}

################################
# PIPELINE CONFIGURATION
################################
resource "bindplane_configuration" "vm_logs_pipeline" {
  rollout  = true
  name     = "vm-logs-${random_id.suffix.hex}"
  platform = "linux"

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }

  source {
    name       = bindplane_source.journald_logs.name
    processors = [bindplane_processor.batch.name]
  }

  destination {
    name = "googlecloud"
  }

  destination {
    name = "googlebucket"
  }
}
