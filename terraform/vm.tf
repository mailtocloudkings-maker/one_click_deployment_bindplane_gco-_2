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

LOG=/var/log/bindplane-startup.log
exec > >(tee -a $LOG) 2>&1

echo "=== STARTUP SCRIPT BEGIN ==="

############################
# OS PACKAGES
############################
apt-get update -y
apt-get install -y postgresql postgresql-contrib curl ca-certificates uuid-runtime

systemctl enable postgresql
systemctl start postgresql

############################
# POSTGRES SETUP
############################
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bindplane') THEN
    CREATE USER bindplane WITH PASSWORD 'StrongPassword@2025';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane;
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane;
SQL

sudo -u postgres psql bindplane <<'SQL'
GRANT USAGE, CREATE ON SCHEMA public TO bindplane;
ALTER SCHEMA public OWNER TO bindplane;
SQL

############################
# INSTALL BINDPLANE (FIXED)
############################
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
chmod +x install-linux.sh
BINDPLANE_SKIP_INIT=1 bash install-linux.sh
rm -f install-linux.sh

############################
# CONFIG FILE
############################
mkdir -p /etc/bindplane

cat <<'EOF' > /etc/bindplane/config.yaml
apiVersion: bindplane.observiq.com/v1

eula:
  accepted: "2023-05-30"

license: |
  qeVeYo7Nr4ez53xDhfWJMLAEGTAPlF9VYhnbjGANqKoYYnkogYIZkI4EpdoREcqj7A4xL16AtkGrqJG5QrNBzZoqBKcCCbFbuNWOvXRRpw5QoPTB0VrHLsn7+EwAA//99bv98mQkAAA==

env: production

mode:
  - all

output: table
rolloutsInterval: 5s

agents:
  auth:
    type: secretKey
    secretKey:
      headers:
        - X-Bindplane-Authorization
        - Authorization
  heartbeatInterval: 30s
  heartbeatTTL: 1m0s
  heartbeatExpiryInterval: 30s
  rebalanceInterval: 1h0m0s
  maxSimultaneousConnections: 10

auth:
  type: system
  username: admin
  password: test
  sessionSecret: d5a08be4-966b-47a3-9974-93061b84061c

network:
  host: 0.0.0.0
  port: "3001"
  tlsMinVersion: "1.3"

agentVersions:
  syncInterval: 1h0m0s
  agentUpgradesFolder: /var/lib/bindplane/agent-upgrades
  clients:
    - bdot

store:
  type: postgres
  maxEvents: 100
  eventMergeWindow: 100ms

  bbolt:
    path: /var/lib/bindplane/storage/bindplane.db

  postgres:
    host: localhost
    port: "5432"
    connectTimeout: 30s
    statementTimeout: 1m0s
    database: bindplane
    sslmode: disable
    username: bindplane
    password: StrongPassword@2025
    maxConnections: 100
    maxLifetime: 6h0m0s
    schema: public

  encryptionProvider:
    cache:
      capacity: 2000
      cacheTimeout: 2m0s

eventBus:
  type: local

  googlePubSub:
    retry:
      maxRetries: 5

  kafka:
    topic: bindplane-op-message-bus
    authType: none
    plainText: {}
    sasl:
      mechanism: plain

  nats:
    server:
      client:
        host: localhost
        port: 4222
      http:
        host: localhost
        port: 8222
      cluster:
        name: bindplane
        host: localhost
        port: 6222
    client:
      endpoint: nats://localhost:4222
      subject: bindplane-event-bus

logging:
  filePath: /var/log/bindplane/bindplane.log
  output: file
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
