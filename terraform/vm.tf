resource "google_compute_instance" "bindplane_vm" {
  name         = "bindplane-vm-${random_id.suffix.hex}"
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

    apt-get update -y
    apt-get install -y curl jq postgresql postgresql-contrib

    systemctl enable postgresql
    systemctl start postgresql

    sudo -u postgres psql <<'SQL'
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='bindplane') THEN
        CREATE ROLE bindplane LOGIN PASSWORD 'bindplane123';
      END IF;
    END $$;
    SQL

    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='bindplane'" | grep -q 1 || \
      sudo -u postgres createdb -O bindplane bindplane

    curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install.sh
    bash install.sh --init
    rm -f install.sh

    systemctl enable bindplane
    systemctl restart bindplane
  SCRIPT
}
