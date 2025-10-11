variable "project_id" {
  description = "GCP project ID"
  default = "decent-rig-471906-h1"
}

variable "gcp_region" {
  description = "Region for resources"
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "Zone for resources"
  default     = "us-central1-a"
}

variable "email_id" {
  description = "User email for OS Login"
  default = "dhruvmvr@gmail.com"
}
