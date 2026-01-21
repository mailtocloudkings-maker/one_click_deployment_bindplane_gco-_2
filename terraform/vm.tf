resource "google_compute_instance" "bindplane_control" {
  name         = "bindplane-control"
  machine_type = "e2-standard-4"
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

# --------------------------------------------------
# OS & Dependencies
# --------------------------------------------------
apt-get update -y
apt-get install -y \
  curl \
  unzip \
  postgresql \
  postgresql-contrib \
  python3 \
  ca-certificates

systemctl enable postgresql
systemctl start postgresql

# --------------------------------------------------
# PostgreSQL: User
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
# PostgreSQL: Database
# --------------------------------------------------
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'bindplane'" | grep -q 1 || \
  sudo -u postgres createdb -O bindplane bindplane

# --------------------------------------------------
# Install BindPlane Server (as-is)
# --------------------------------------------------
curl -fsSlL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --init
rm -f install-linux.sh

# --------------------------------------------------
# Stop BindPlane before config
# --------------------------------------------------
systemctl stop bindplane || true

# --------------------------------------------------
# Python script: create config.yaml ONLY
# --------------------------------------------------
cat <<'PYEOF' > /root/create_bindplane_config.py
from pathlib import Path

config = Path("/etc/bindplane/config.yaml")
config.parent.mkdir(parents=True, exist_ok=True)

config.write_text("""
apiVersion: bindplane.observiq.com/v1
env: production

network:
  host: 0.0.0.0
  port: "3001"

auth:
  type: system
  username: admin
  password: test

store:
  type: postgres
  postgres:
    host: localhost
    port: "5432"
    database: bindplane
    username: bindplane
    password: bindplane123
    sslmode: disable
""")

print("config.yaml created successfully")
PYEOF

python3 /root/create_bindplane_config.py

# --------------------------------------------------
# Permissions
# --------------------------------------------------
chown bindplane:bindplane /etc/bindplane/config.yaml
chmod 600 /etc/bindplane/config.yaml

# --------------------------------------------------
# Enable & Start BindPlane
# --------------------------------------------------
systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane
systemctl status bindplane --no-pager

echo "=== BindPlane startup script completed ==="
SCRIPT
}
