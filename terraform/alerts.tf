resource "google_monitoring_notification_channel" "email" {
  display_name = "bindplane-alert-email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "cpu" {
  display_name = "BindPlane High CPU"

  conditions {
    display_name = "CPU Utilization > 80%"

    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]
}
