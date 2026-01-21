resource "google_compute_instance" "bindplane_control" {
  name         = "bindplane-control-${random_id.suffix.hex}"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["bindplane"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  ################################
  # Startup Script
  ################################
  metadata_startup_script = <<-SCRIPT
#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/bindplane-startup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== BindPlane startup started ==="

apt-get update -y
apt-get install -y \
  python3 \
  curl \
  unzip \
  postgresql \
  postgresql-contrib \
  ca-certificates \
  uuid-runtime

systemctl enable postgresql
systemctl start postgresql

mkdir -p /opt/bindplane
cat >/opt/bindplane/setup_bindplane.py <<'PYTHON'
$(sed 's/^/    /' terraform/scripts/setup_bindplane.py 2>/dev/null || true)
PYTHON

python3 /opt/bindplane/setup_bindplane.py

echo "=== BindPlane startup completed ==="
SCRIPT
}
