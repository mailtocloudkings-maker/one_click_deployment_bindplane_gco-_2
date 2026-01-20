# Generate SSH key pair
resource "tls_private_key" "bindplane_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# BindPlane VM
resource "google_compute_instance" "bindplane_control" {
  name         = "bindplane-control-${random_id.suffix.hex}"
  machine_type = "e2-medium"        # smaller machine type to avoid quota issues
  zone         = var.zone
  tags         = ["bindplane"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  # DEFAULT VPC + DEFAULT SUBNET
  network_interface {
    network = "default"
    access_config {}
  }

  # Inject SSH public key
  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.bindplane_ssh.public_key_openssh}"
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail

    LOG_FILE="/var/log/bindplane-startup.log"
    exec > >(tee -a $LOG_FILE) 2>&1

    echo "=== Bindplane startup script started ==="

    # --------------------------------------------------
    # OS Update & Dependencies
    # --------------------------------------------------
    apt-get update -y
    apt-get install -y curl unzip postgresql postgresql-contrib

    systemctl enable postgresql
    systemctl start postgresql

    # --------------------------------------------------
    # PostgreSQL: Create user (idempotent)
    # --------------------------------------------------
    sudo -u postgres psql <<'SQL'
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane') THEN
        CREATE ROLE bindplane LOGIN PASSWORD 'bindplane123';
      END IF;
    END
    $$;
    SQL

    # --------------------------------------------------
    # PostgreSQL: Create database (idempotent)
    # --------------------------------------------------
    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'bindplane'" | grep -q 1 || \
      sudo -u postgres createdb -O bindplane bindplane

    # --------------------------------------------------
    # Install BindPlane Server
    # --------------------------------------------------
    curl -fsSlL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
    bash install-linux.sh --init
    rm -f install-linux.sh

    # --------------------------------------------------
    # Enable & Start BindPlane
    # --------------------------------------------------
    systemctl daemon-reload
    systemctl enable bindplane
    systemctl restart bindplane

    echo "=== Bindplane startup script completed ==="
  SCRIPT
}
