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
  # STARTUP SCRIPT (MUST BE HERE)
  ################################
  metadata_startup_script = <<-SCRIPT
#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/bindplane-startup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== BindPlane startup script started ==="

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

cat >/root/setup_bindplane.py <<'PYTHON'
import subprocess
import textwrap
import os

def run(cmd):
    subprocess.run(cmd, shell=True, check=True)

run("""sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane_user') THEN
    CREATE USER bindplane_user WITH PASSWORD 'StrongPassword@2025';
  END IF;
END
$$;
SQL""")

run("""sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane_user;
  END IF;
END
$$;
SQL""")

run("""sudo -u postgres psql <<'SQL'
GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane_user;
\\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO bindplane_user;
ALTER SCHEMA public OWNER TO bindplane_user;
SQL""")

run("""
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o /tmp/install-linux.sh
chmod +x /tmp/install-linux.sh
/tmp/install-linux.sh --init
""")

config_yaml = textwrap.dedent("""\
apiVersion: bindplane.observiq.com/v1
eula:
  accepted: "2023-05-30"
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
    username: bindplane_user
    password: StrongPassword@2025
    sslmode: disable
""")

os.makedirs("/etc/bindplane", exist_ok=True)
with open("/etc/bindplane/config.yaml", "w") as f:
    f.write(config_yaml)

run("chown -R bindplane:bindplane /etc/bindplane")
run("chmod 600 /etc/bindplane/config.yaml")

run("systemctl daemon-reload")
run("systemctl enable bindplane")
run("systemctl restart bindplane")
PYTHON

python3 /root/setup_bindplane.py

echo "=== BindPlane startup script completed ==="
SCRIPT
}
