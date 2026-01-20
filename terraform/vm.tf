################################
# SSH KEY (optional)
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

  network_interface {
    network = "default"
    access_config {}
  }

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

echo "=== BindPlane startup started ==="

################################
# OS & Dependencies
################################
apt-get update -y
apt-get install -y curl unzip ca-certificates uuid-runtime \
                   postgresql postgresql-contrib

systemctl enable postgresql
systemctl start postgresql

################################
# PostgreSQL: USER + DB (IDEMPOTENT)
################################
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  -- Create user
  IF NOT EXISTS (
    SELECT FROM pg_roles WHERE rolname = 'bindplane_user'
  ) THEN
    CREATE USER bindplane_user WITH PASSWORD 'StrongPassword@2025';
  END IF;

  -- Create database
  IF NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'bindplane'
  ) THEN
    CREATE DATABASE bindplane OWNER bindplane_user;
  END IF;
END
$$;
SQL

################################
# PostgreSQL: GRANTS
################################
sudo -u postgres psql <<'SQL'
GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane_user;
SQL

################################
# PostgreSQL: SCHEMA PERMISSIONS
################################
sudo -u postgres psql -d bindplane <<'SQL'
GRANT USAGE, CREATE ON SCHEMA public TO bindplane_user;
ALTER SCHEMA public OWNER TO bindplane_user;
SQL

################################
# Install BindPlane Server
################################
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --init
rm -f install-linux.sh

systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane

################################
# Wait for BindPlane API
################################
echo "Waiting for BindPlane API..."
sleep 30

################################
# Install BindPlane Agent (LOCAL)
################################
curl -fsSL https://bdot.bindplane.com/v1.89.0/install_unix.sh -o install_unix.sh
chmod +x install_unix.sh

./install_unix.sh \
  -e "ws://localhost:3001/v1/opamp" \
  -v "1.89.0" \
  -k "install_id=$(uuidgen)"

systemctl daemon-reexec
systemctl enable bindplane-agent
systemctl restart bindplane-agent

echo "=== BindPlane startup completed ==="
SCRIPT
}
