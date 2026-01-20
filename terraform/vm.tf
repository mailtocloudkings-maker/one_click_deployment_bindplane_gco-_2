################################
# SSH KEY (optional, safe to keep)
################################
resource "tls_private_key" "bindplane_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

################################
# BindPlane Control VM
################################
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

  # DEFAULT VPC
  network_interface {
    network = "default"
    access_config {}
  }

  # Inject SSH key (optional, not required by pipeline)
  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.bindplane_ssh.public_key_openssh}"
  }

  ################################
  # STARTUP SCRIPT
  ################################
  metadata_startup_script = <<-SCRIPT
#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/bindplane-startup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== BindPlane startup script started ==="

# -------------------------------
# OS & dependencies
# -------------------------------
apt-get update -y
apt-get install -y curl unzip postgresql postgresql-contrib ca-certificates uuid-runtime

systemctl enable postgresql
systemctl start postgresql

# -------------------------------
# PostgreSQL user (idempotent)
# -------------------------------
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane') THEN
    CREATE ROLE bindplane LOGIN PASSWORD 'bindplane123';
  END IF;
END
$$;
SQL

# -------------------------------
# PostgreSQL DB (idempotent)
# -------------------------------
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'bindplane'" | grep -q 1 || \
  sudo -u postgres createdb -O bindplane bindplane

# -------------------------------
# Install BindPlane Server
# -------------------------------
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --init
rm -f install-linux.sh

systemctl daemon-reload
systemctl start bindplane
systemctl enable bindplane
systemctl restart bindplane

# -------------------------------
# Wait for BindPlane API
# -------------------------------
echo "Waiting for BindPlane server..."
sleep 30

# -------------------------------
# Install BindPlane Agent
# -------------------------------
echo "Installing BindPlane Agent..."

curl -fsSL https://bdot.bindplane.com/v1.89.0/install_unix.sh -o install_unix.sh
chmod +x install_unix.sh

./install_unix.sh \
  -e "ws://localhost:3001/v1/opamp" \
  -v "1.89.0" \
  -k "install_id=$(uuidgen)"

systemctl daemon-reexec
systemctl start bindplane-agent
systemctl enable bindplane-agent
systemctl restart bindplane-agent

echo "=== BindPlane startup script completed ==="
SCRIPT
}
