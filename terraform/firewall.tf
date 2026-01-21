resource "google_compute_firewall" "bindplane_fw" {
  name    = "bindplane-fw-${random_id.suffix.hex}"
  network = "default"

  description = "Firewall for Bindplane VM: SSH, HTTP, HTTPS, App (3001), Postgres (5432)"

  # Allowed protocols and ports
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3001", "5432"]
  }

  # Source ranges: allow from anywhere
  source_ranges = ["0.0.0.0/0"]

  # Target VM(s) by network tag
  target_tags = ["bindplane"]

  # Optional: log denied connections
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
