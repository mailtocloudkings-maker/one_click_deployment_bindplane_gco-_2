resource "null_resource" "install_bindplane_agent" {
  depends_on = [
    google_compute_instance.bindplane_control
  ]

  # Use the SSH key generated in vm.tf
  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = google_compute_instance.bindplane_control.network_interface[0].access_config[0].nat_ip
    private_key = tls_private_key.bindplane_ssh.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      # Download and install BindPlane Agent
      "curl -fsSL https://storage.googleapis.com/bindplane-op-releases/agent/latest/install-linux.sh -o install-agent.sh",
      "sudo bash install-agent.sh",

      # Enable and start the agent
      "sudo systemctl enable bindplane-agent",
      "sudo systemctl restart bindplane-agent"
    ]
  }
}
