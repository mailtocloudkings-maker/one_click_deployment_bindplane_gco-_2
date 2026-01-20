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

# Create the config directory if it doesn't exist
sudo mkdir -p /etc/bindplane

# Overwrite /etc/bindplane/config.yaml with your full YAML
sudo tee /etc/bindplane/config.yaml > /dev/null <<'EOF'
apiVersion: bindplane.observiq.com/v1
eula:
  accepted: "2023-05-30"
license: H4sIAAAAAAAA/1RVCXPayBL+K7HyUolfYb8Z3aLqVdbG5oqFY2wjwLPHXLKEERAOI0iyv32rWwzepJKJmKOPr7/++ruVK6tuSUI5dU>
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
  ldap:
    protocol: ldap
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
    username: bindplane_user
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
  azure:
    cloud: public
  health:
    requiredHosts: 1
    interval: 15s
logging:
  filePath: /var/log/bindplane/bindplane.log
  output: file
  otlp:
    endpoint: localhost:4317
    interval: 1s
metrics:
  interval: 1m0s
  prometheus:
    endpoint: /metrics
transformAgent:
  transformAgentsFolder: /var/lib/bindplane/transform-agents
auditTrail:
  retentionDays: 30
pprof:
  enabled: false
  endpoint: 127.0.0.1:6060
profiling:
  enabled: false
  projectID: ""
  serviceName: bindplane
  noCPU: false
  noAlloc: false
  noHeap: false
  noGoroutine: false
  mutex: false
maxConcurrency: 10
prometheus:
  localFolder: /var/lib/bindplane/prometheus
  host: localhost
  port: "9090"
  remoteWrite:
    endpoint: /api/v1/write
  auth:
    type: basic
    username: prometheus
    password: qvAWI0nIJQ+JTKn/hM/zNmoxBY5KKOW9
analytics:
  segmentWriteKey: 36hUTo2RZxoaodC3w4TcIFxph9VAFYxB
advanced:
  store:
    stats:
      batchFlushInterval: 1s
      workerCount: 1
  server:
    maxRequestBytes: 10485760
  agent:
    telemetryPort: 8888
  rollout:
  retry:
      interval: 30s
    updateWorkerCount: 10
features:
  type: default
  posthog:
    featureFlagRequestTimeout: 30s
    defaultFeatureFlagsPollingInterval: 5m0s
llm:
  gemini: {}
  openai: {}
  anthropic: {}
quotas:
  organizations:
    default:
      maxAgents: 2000
  projects:
    default:
      maxAgents: 1000
EOF

# Fix permissions so BindPlane service can read it
sudo chown -R bindplane:bindplane /etc/bindplane
sudo chmod 600 /etc/bindplane/config.yaml

# -------------------------------
# Start BindPlane
# -------------------------------
systemctl daemon-reload
systemctl enable bindplane
systemctl restart bindplane

echo "=== BindPlane startup script completed ==="
SCRIPT
}
