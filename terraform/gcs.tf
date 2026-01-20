resource "google_storage_bucket" "logs" {
  name     = "bindplane-logs-${random_id.suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true
}
