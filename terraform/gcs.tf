resource "google_storage_bucket" "logs" {
  name     = "bindplane-logs-${random_id.suffix.hex}"
  location = var.region               # must be region only, e.g., us-central1
  force_destroy = true
  uniform_bucket_level_access = true
}
