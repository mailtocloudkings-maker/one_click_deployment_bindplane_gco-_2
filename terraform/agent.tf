resource "null_resource" "bindplane_agent" {
  depends_on = [google_compute_instance.bindplane_vm]

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    }

    inline = [
      "curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane-agent/latest/install-linux.sh | sudo bash",
      "sudo systemctl enable bindplane-agent",
      "sudo systemctl restart bindplane-agent"
    ]
  }
}
