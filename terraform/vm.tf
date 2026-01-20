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
apt-get install -y \
  curl \
  unzip \
  postgresql \
  postgresql-contrib \
  ca-certificates \
  uuid-runtime

systemctl enable postgresql
systemctl start postgresql

# -------------------------------
# PostgreSQL user
# -------------------------------
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane_user') THEN
    CREATE USER bindplane_user WITH PASSWORD 'StrongPassword@2025';
  END IF;
END
$$;
SQL

# -------------------------------
# PostgreSQL database
# -------------------------------
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane_user;
  END IF;
END
$$;
SQL

# -------------------------------
# Grant privileges
# -------------------------------
sudo -u postgres psql <<'SQL'
GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane_user;
\\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO bindplane_user;
ALTER SCHEMA public OWNER TO bindplane_user;
SQL

# -------------------------------
# Install BindPlane Server
# -------------------------------
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --init
rm -f install-linux.sh

# -------------------------------
# WRITE BindPlane config.yaml
# -------------------------------
mkdir -p /etc/bindplane

cat <<'EOF' > /etc/bindplane/config.yaml
store:
  type: postgres
  postgres:
    host: localhost
    port: 5432
    database: bindplane
    user: bindplane_user
    password: StrongPassword@2025
    sslmode: disable
EOF

chown -R bindplane:bindplane /etc/bindplane
chmod 600 /etc/bindplane/config.yaml

# -------------------------------
# Start BindPlane
# -------------------------------
systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane

echo "=== BindPlane startup script completed ==="
SCRIPT
}
