# ------------------------
# variables.tf
# ------------------------

variable "zone" {
  description = "GCP zone for VM"
  type        = string
  default     = "us-central1-a"
}

variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
}
