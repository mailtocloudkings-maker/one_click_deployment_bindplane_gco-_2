resource "google_logging_project_sink" "gcs_sink" {
  name        = "bindplane-sink-${random_id.suffix.hex}"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  filter      = "resource.type=gce_instance"
}
