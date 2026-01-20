variable "project_id" {}
variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "alert_email" {}

variable "bindplane_api_key" {
  default = ""
}
