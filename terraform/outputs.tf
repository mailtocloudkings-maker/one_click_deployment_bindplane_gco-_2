output "bindplane_ui_url" {
  value = "http://${google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip}:3001"
}

output "gcs_bucket" {
  value = google_storage_bucket.logs.name
}

output "bindplane_vm_ip" {
  value = google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip
}
