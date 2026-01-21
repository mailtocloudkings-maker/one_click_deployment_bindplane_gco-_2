import subprocess
import textwrap
import os

def run(cmd):
    subprocess.run(cmd, shell=True, check=True)

# PostgreSQL setup
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

# Install BindPlane
run("""
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o /tmp/install-bindplane.sh
chmod +x /tmp/install-bindplane.sh
/tmp/install-bindplane.sh --init
""")

# Write config.yaml (NO PROMPTS)
config = textwrap.dedent("""\
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
    f.write(config)

run("chown -R bindplane:bindplane /etc/bindplane")
run("chmod 600 /etc/bindplane/config.yaml")

run("systemctl daemon-reload")
run("systemctl enable bindplane")
run("systemctl restart bindplane")
