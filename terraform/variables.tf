# ------------------------
# variables.tf
# ------------------------

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
}

variable "zone" {
  description = "GCP zone for VM"
  type        = string
  default     = "us-central1-a"
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
}
