resource "google_storage_bucket" "logs" {
  name          = "bindplane-logs-${random_id.suffix.hex}"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

