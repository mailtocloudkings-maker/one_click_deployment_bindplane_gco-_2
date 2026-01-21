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

  # ENABLE SERIAL CONSOLE LOGGING
  metadata = {
    serial-port-enable = "true"
  }

  # CALL PYTHON SCRIPT
  metadata_startup_script = <<-SCRIPT
#!/bin/bash
set -euxo pipefail

LOG=/var/log/bindplane-startup.log
exec > >(tee -a $LOG | logger -t bindplane-startup) 2>&1

echo "==== STARTUP SCRIPT BEGIN ===="

apt-get update -y
apt-get install -y python3 python3-pip curl ca-certificates postgresql uuid-runtime

# Copy python script
cat <<'PYEOF' > /root/setup_bindplane.py
$(cat terraform/scripts/setup_bindplane.py)
PYEOF

chmod +x /root/setup_bindplane.py
python3 /root/setup_bindplane.py

echo "==== STARTUP SCRIPT END ===="
SCRIPT
}
