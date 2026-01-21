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

  metadata_startup_script = &lt;&lt;-SCRIPT
#!/bin/bash
LOG=/var/log/bindplane-startup.log
exec &gt; &gt;(tee -a $LOG) 2&gt;&amp;1

echo "=== STARTUP SCRIPT BEGIN ==="

############################
# OS PACKAGES
############################
apt-get update -y
apt-get install -y curl postgresql postgresql-contrib

systemctl enable postgresql
systemctl start postgresql

############################
# POSTGRES SETUP
############################
sudo -u postgres psql &lt;&lt;'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='bindplane') THEN
    CREATE USER bindplane WITH PASSWORD 'bindplane123';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname='bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane;
  END IF;
END $$;
SQL

############################
# INSTALL BINDPLANE (NON-INTERACTIVE)
############################
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o /tmp/install-bindplane.sh
chmod +x /tmp/install-bindplane.sh

# NON-INTERACTIVE INSTALL
yes | /tmp/install-bindplane.sh --init || true

############################
# WAIT FOR FILES
############################
sleep 10
mkdir -p /etc/bindplane

############################
# FORCE CONFIG (DELETE + REPLACE)
############################
cat &lt;&lt;'EOF' &gt; /etc/bindplane/config.yaml
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
EOF

############################
# PERMISSIONS
############################
chown -R bindplane:bindplane /etc/bindplane
chmod 600 /etc/bindplane/config.yaml

############################
# START SERVICE
############################
systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane

sleep 5
systemctl status bindplane --no-pager || true

echo "=== STARTUP SCRIPT END ==="
SCRIPT
}
