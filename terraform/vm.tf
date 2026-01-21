resource "google_compute_instance" "bindplane_control" {
  name         = "bindplane-control-${random_id.suffix.hex}"
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
set -e
LOG=/var/log/bindplane-startup.log
exec > >(tee -a $LOG) 2>&1

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

# Create database if it does not exist
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'bindplane'" | grep -q 1 || \
sudo -u postgres psql -c "CREATE DATABASE bindplane;"

# Create user if it does not exist
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname = 'bindplane'" | grep -q 1 || \
sudo -u postgres psql -c "CREATE USER bindplane WITH PASSWORD 'StrongPassword@2025';"

# Ownership and privileges
sudo -u postgres psql -c "ALTER DATABASE bindplane OWNER TO bindplane;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bindplane TO bindplane;"

# Schema permissions
sudo -u postgres psql -d bindplane -c "GRANT USAGE, CREATE ON SCHEMA public TO bindplane;"
sudo -u postgres psql -d bindplane -c "ALTER SCHEMA public OWNER TO bindplane;"



############################
# INSTALL BINDPLANE (NO INIT)
############################
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o /tmp/install-bindplane.sh
chmod +x /tmp/install-bindplane.sh

# ✅ SAFE NON-INTERACTIVE INSTALL
/tmp/install-bindplane.sh

systemctl start bindplane
############################
# CONFIGURATION
############################
mkdir -p /etc/bindplane

cat <<'EOF' > /etc/bindplane/config.yaml

apiVersion: bindplane.observiq.com/v1

eula:
  accepted: "2023-05-30"

license: |
  H4sIAAAAAAAA/1RVCXPayBL+K7HyUolfYb8Z3aLqVdbG5oqFY2wjwLPHXLKEERAOI0iyv32rWwzepJKJmKOPr7/++ruVK6tuSUI5dUJyllJfnrnU886iUNMz5WvfcaStU+laNWu9W2irbrXm8+eptmrWfDvTS6tu8ek6L/R6mb9YNUuXi3zJ1/l8ZtUtm9reGbXPKHkgpI5/x1bNWuXPM77eLMEas54ZK0N7y1gZScZKTWewRoyVRDNWCpsxzliZ2jW4GP4HvgljpbQ12xDi6OQ9Ht9NYFO+A0M2WvsJ+y6cRmBBwqvIT2EXFs0Z/imFz1ipQrgYBmZJBURA4SfNGCup+gBvwo8C//udsZJ7H1fwnDtwi8CWcNEJiRjbEMo13oXFXp0R/Qfs2hqMps4FrD7suAoC4LDIIAFfYFBFJooIvngw9sABWKPgRAQ5RGh/hkOFUAB+3FX4GHGKVB9CQ/zUX7AvcRueYxR+G5yCEyrMiUxPGSuDlDGB+EPeoQuP/SYcA2wWeBLGNsUAXfwJ8YXHSDVuQjkUxKzFAqoo6SH3MqIIiYSwQoGZnH9AHGEDdiP4EuiAVJmyMqUIiImBkv/C6kEBCEAXhYwBi6I3HGV3i+SCDRd8+mF4j3w4HSHO8RuCFUPOXUQNH4N5jumcGDCAl6VUFTnDECmIxQQgeQl+qt/IiFBhcpxi4RAJZBZ86V9gFIBdCHuprowrVQNDXgjZpN7rIcEUg0pODBRVVbFv/K8mV+mZZgrTpx9IRLgf/R/sanNGsWoEK0SO3HDeGVZyX9WZBd1d8Hxq1a0VX/KJnqkln/321v7ncl5YNUvxNbfqlt51F+NGx+8U8TZOrst4/7y9SUZlr4jXvatr2rsn3m3rsbxJ7uzxw2gf2/FunIwnvUZn1Zn1Pdl6zG/zblvY0Uy0HvObRvdV2d5U5mCzuVKt6Xo87O94ssIzWahMFFN/NOwvhO110ffkorwn8TaZNL88DOa7O/pMBy9k//iierfNy2HvSu46+TYfD7MtH3Yz1Zq+CrA/6ZTx5HEdP3TW8cPlY3x14Vf/LjneT2jGky3Etx8NuxkvBptxu5uJl8tMtPsLkQyILKbLm6L3Ku47q04x3Q/a3cUI3hTjTLR705tGdz0aZpdje7BR7Ti/nVysOgXNdHOwHw+7+85kvj3cuZNF9G2c9Ijcdfy4sc1F0nT7reZCtKddUaipdPq9u7w6k3YzkyTaiPbLv30txKw/lYWXiUbHHxfNlbQH0aFaf/6qyEAw4L1IURdvgBaeNrSkSFDkovi0n02NUGuvZhpSEKOi2OmoL0g86j19i44/bFSB4afPKNnXRvi0OjR7pTK+0VBsZOlcYiPdfYfH4UFCqlsEyY4Krr4ZsUNthYsb4jv4nTqo3SeH1g2qDsdRolGNHBQaMFapGdwQ+tgxODuCwqgUFY33ZlSk7nF4CRTdAJPC1NxzVFWCT+AFxaSc1ez7UV4wdo8f5LeUYg9HGsUBGzF6Q5uxTRoECich6F/KDQQUvYqnr0dVFocX1QwE1SqDNDkMxg0JwvT8WN7o78sA0b56SwDF1DcFksFhBm0ItX2DFRYdsRWKsU1oi/Qah9fH9yGga/tm8Ibii5m6OClwXEPB0Q315x+OdaGIHM4McmoqgMThDof5LqvZjXL7E8OqeVeYo7Nr4ez53xDhfWJMLAEGTAPlF9VYhnbjGANqKoYYnkogYIZkI4EpdoREcqj7A4xL16AtkGrqJG5QrNBzZoqBKcCCbFbuNWOvXRRpw5QoPTB0VrHLsn7+EwAA//99bv98mQkAAA==

env: production
mode:
  - all

output: table
rolloutsInterval: 5s
network:
    host: 0.0.0.0
    port: "3001"
    tlsMinVersion: "1.3"
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

  network:
    host: 0.0.0.0
    port: "3001"
    tlsMinVersion: "1.3"

  admin:
    auth:
      type: system
      username: admin
      password: test
      sessionSecret: d5a08be4-966b-47a3-9974-93061b84061c

  ldap:
    protocol: ldap

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
systemctl start bindplane

sleep 10
systemctl status bindplane --no-pager

echo "=== STARTUP SCRIPT END ==="
SCRIPT
}
