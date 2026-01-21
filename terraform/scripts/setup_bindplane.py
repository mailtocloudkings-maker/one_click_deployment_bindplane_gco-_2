#!/usr/bin/env python3
import subprocess
import time
from pathlib import Path

def run(cmd):
    print(f"▶ {cmd}")
    subprocess.run(cmd, shell=True, check=True)

print("=== SETUP START ===")

# PostgreSQL
run("systemctl enable postgresql")
run("systemctl start postgresql")

run("""sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='bindplane_user') THEN
    CREATE USER bindplane_user WITH PASSWORD 'StrongPassword@2025';
  END IF;
END$$;
SQL""")

run("""sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname='bindplane') THEN
    CREATE DATABASE bindplane OWNER bindplane_user;
  END IF;
END$$;
SQL""")

# Install BindPlane
run("curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install.sh")
run("bash install.sh --init")
run("rm -f install.sh")

# Stop service before config
run("systemctl stop bindplane")

# Write config
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
    username: bindplane_user
    password: StrongPassword@2025
    sslmode: disable
""")

run("chown bindplane:bindplane /etc/bindplane/config.yaml")
run("chmod 600 /etc/bindplane/config.yaml")

# Start service
run("systemctl daemon-reload")
run("systemctl enable bindplane")
run("systemctl restart bindplane")

print("=== SETUP COMPLETE ===")
