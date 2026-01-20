variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "zone" {
  description = "GCP zone (e.g., us-central1-a)"
  type        = string
}

variable "region" {
  description = "GCP region (e.g., us-central1)"
  type        = string
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
}
