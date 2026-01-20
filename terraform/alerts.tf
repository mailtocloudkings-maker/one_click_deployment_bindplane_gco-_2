resource "google_monitoring_notification_channel" "email" {
  display_name = "bindplane-alert-email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "cpu" {
  display_name = "BindPlane High CPU"
  combiner     = "OR"

  conditions {
    display_name = "CPU Utilization > 80%"

    condition_threshold {
      filter = <<EOT
resource.type="gce_instance"
AND metric.type="compute.googleapis.com/instance/cpu/utilization"
EOT

      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]
}
