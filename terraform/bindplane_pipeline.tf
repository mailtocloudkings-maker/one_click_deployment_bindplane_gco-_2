################################
# Generate BindPlane API Key
################################
resource "null_resource" "bindplane_api_key" {
  depends_on = [google_compute_instance.bindplane_control]

  provisioner "local-exec" {
    command = <<EOT
set -e

SERVER_IP=$(terraform output -raw bindplane_vm_ip)

echo "Waiting 30 seconds for BindPlane..."
sleep 30

TOKEN=$(curl -s -X POST http://$SERVER_IP:3001/v1/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password*test"}' | jq -r '.token')

API_KEY=$(curl -s -X POST http://$SERVER_IP:3001/v1/api-keys \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"terraform-key"}' | jq -r '.key')

mkdir -p terraform
echo "$API_KEY" > terraform/bindplane_api_key.txt
EOT
  }
}

################################
# Read API Key from File
################################
data "local_file" "bindplane_api_key" {
  depends_on = [null_resource.bindplane_api_key]
  filename   = "${path.module}/bindplane_api_key.txt"
}

################################
# BindPlane Provider (NO VARIABLE)
################################
provider "bindplane" {
  remote_url = "http://${google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip}:3001"
  api_key    = trimspace(data.local_file.bindplane_api_key.content)
}

################################
# SOURCES
################################
resource "bindplane_source" "journald_logs" {
  rollout = true
  name    = "journald-logs"
  type    = "journald"
}

resource "bindplane_source" "host_metrics" {
  rollout = true
  name    = "host-metrics"
  type    = "host"
}

################################
# PROCESSOR
################################
resource "bindplane_processor" "batch" {
  rollout = true
  name    = "batch"
  type    = "batch"
}

################################
# CONFIGURATION
################################
resource "bindplane_configuration" "logs" {
  rollout  = true
  name     = "vm-logs"
  platform = "linux"

  source {
    name       = bindplane_source.journald_logs.name
    processors = [bindplane_processor.batch.name]
  }

  destination {
    name = "googlebucket"
  }
}
