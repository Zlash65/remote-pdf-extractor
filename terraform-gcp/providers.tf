provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region

  billing_project = var.billing_project_override != "" ? var.billing_project_override : null
}
