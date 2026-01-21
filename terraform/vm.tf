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
    subnetwork = google_compute_subnetwork.bindplane_subnet.name
    access_config {}
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail

    LOG_FILE="/var/log/bindplane-startup.log"
    exec > >(tee -a $LOG_FILE) 2>&1

    echo "===== BindPlane startup BEGIN ====="

    # --------------------------------------------------
    # OS & dependencies
    # --------------------------------------------------
    apt-get update -y
    apt-get install -y \
      curl \
      unzip \
      python3 \
      postgresql \
      postgresql-contrib \
      ca-certificates

    systemctl enable postgresql
    systemctl start postgresql

    # --------------------------------------------------
    # PostgreSQL: user + database
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

    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='bindplane'" | grep -q 1 || \
      sudo -u postgres createdb -O bindplane bindplane

    sudo -u postgres psql <<'SQL'
    GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane;
    \\c bindplane
    GRANT USAGE, CREATE ON SCHEMA public TO bindplane;
    ALTER SCHEMA public OWNER TO bindplane;
    SQL

    # --------------------------------------------------
    # Install BindPlane Server
    # --------------------------------------------------
    curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o /tmp/install-bindplane.sh
    bash /tmp/install-bindplane.sh --init
    rm -f /tmp/install-bindplane.sh

    # --------------------------------------------------
    # Stop BindPlane before config overwrite
    # --------------------------------------------------
    systemctl stop bindplane || true

    # --------------------------------------------------
    # INLINE Python: wipe & replace config.yaml
    # --------------------------------------------------
    python3 - <<'PYEOF'
from pathlib import Path

config_path = Path("/etc/bindplane/config.yaml")

config_content = """apiVersion: bindplane.observiq.com/v1
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
"""

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(config_content)

print("BindPlane config.yaml overwritten successfully")
PYEOF

    # --------------------------------------------------
    # Permissions
    # --------------------------------------------------
    chown bindplane:bindplane /etc/bindplane/config.yaml
    chmod 600 /etc/bindplane/config.yaml

    # --------------------------------------------------
    # Start BindPlane
    # --------------------------------------------------
    systemctl daemon-reload
    systemctl enable bindplane
    systemctl restart bindplane

    echo "===== BindPlane startup COMPLETE ====="
  SCRIPT
}
