resource "null_resource" "install_bindplane_agent" {
  depends_on = [google_compute_instance.bindplane_control]

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip
    }

    inline = [
      "curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane-agent/latest/install-linux.sh | sudo bash",
      "sudo systemctl enable bindplane-agent",
      "sudo systemctl restart bindplane-agent"
    ]
  }
}
