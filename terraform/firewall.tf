resource "google_compute_firewall" "bindplane_fw" {
  name    = "bindplane-fw-${random_id.suffix.hex}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3001", "5432"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bindplane"]
}
