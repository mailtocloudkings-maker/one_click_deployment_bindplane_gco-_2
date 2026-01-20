# BindPlane VM with fully automated config
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
apt-get install -y curl unzip postgresql postgresql-contrib ca-certificates uuid-runtime

systemctl enable postgresql
systemctl start postgresql

# -------------------------------
# PostgreSQL user & database
# -------------------------------
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane_user') THEN
    CREATE USER bindplane_user WITH PASSWORD 'StrongPassword@2025';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane_user;
  END IF;
END
$$;

sudo -u postgres psql <<'SQL'
GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane_user;
\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO bindplane_user;
ALTER SCHEMA public OWNER TO bindplane_user;
SQL

# -------------------------------
# Install BindPlane Server (non-interactive)
# -------------------------------
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
chmod +x install-linux.sh
bash install-linux.sh --init
rm -f install-linux.sh

# -------------------------------
# Write fully configured config.yaml (pre-populate all prompts)
# -------------------------------
sudo mkdir -p /etc/bindplane
sudo tee /etc/bindplane/config.yaml > /dev/null <<'EOF'
apiVersion: bindplane.observiq.com/v1
eula:
  accepted: "2023-05-30"
license: H4sIAAAAAAAA/1RVCXPayBL+K7HyUolfYb8Z3aLqVdbG5oqFY2wjwLPHXLKEERAOI0iyv32rWwzepJKJmKOPr7/++ruVK6tuSUI5dU>
env: production
mode:
- all
output: table
network:
  host: 0.0.0.0          # IP to listen on (skip prompt)
  port: "3001"           # Port (skip prompt)
agentVersions:
  clients:
  - bdot
auth:
  type: system
  username: admin        # pre-set username
  password: test         # pre-set password
  sessionSecret: d5a08be4-966b-47a3-9974-93061b84061c
store:
  type: postgres
  postgres:
    host: localhost
    port: "5432"
    database: bindplane
    username: bindplane_user
    password: StrongPassword@2025
    sslmode: disable
    maxConnections: 100
    maxLifetime: 6h0m0s
    schema: public
EOF

# -------------------------------
# Fix permissions
# -------------------------------
sudo chown -R bindplane:bindplane /etc/bindplane
sudo chmod 600 /etc/bindplane/config.yaml

# -------------------------------
# Start BindPlane service
# -------------------------------
systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane

echo "=== BindPlane startup script completed ==="
SCRIPT
}
