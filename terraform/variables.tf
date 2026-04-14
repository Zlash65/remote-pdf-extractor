variable "TFC_WORKSPACE_NAME" {
  description = "Optional Terraform Cloud workspace name used to derive the environment."
  type        = string
  default     = ""
}

variable "resource_name_prefix" {
  description = "Optional prefix for resource names. When empty, Terraform derives it from TFC_WORKSPACE_NAME when possible or falls back to pdf-extractor."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Explicit environment name. When empty, derive from TFC_WORKSPACE_NAME or fall back to shared."
  type        = string
  default     = ""
}

variable "gcp_project_id" {
  description = "Google Cloud project ID where the Cloud Function will be deployed."
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud region for the Cloud Function."
  type        = string
  default     = "us-central1"
}

variable "billing_project_override" {
  description = "Optional billing project for the Terraform provider itself when required by your auth setup."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Additional GCP labels to apply to supported resources."
  type        = map(string)
  default     = {}
}

variable "terraform_runner_member" {
  description = "IAM member string for the identity running Terraform, for example serviceAccount:pdf-extractor-deployer@PROJECT_ID.iam.gserviceaccount.com. Terraform grants this principal roles/iam.serviceAccountUser on the function runtime service account."
  type        = string

  validation {
    condition     = trimspace(var.terraform_runner_member) != ""
    error_message = "terraform_runner_member is required. Set it to the Terraform deployer IAM member string, for example serviceAccount:pdf-extractor-deployer@PROJECT_ID.iam.gserviceaccount.com."
  }
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Function instances."
  type        = number
  default     = 10
}

variable "min_instance_count" {
  description = "Minimum number of Cloud Function instances (0 = scale to zero)."
  type        = number
  default     = 0
}

variable "available_memory" {
  description = "Memory allocated to each Cloud Function instance."
  type        = string
  default     = "512Mi"
}

variable "timeout_seconds" {
  description = "Maximum execution time for the Cloud Function in seconds."
  type        = number
  default     = 120
}

variable "available_cpu" {
  description = "CPU allocated to each Cloud Function instance."
  type        = string
  default     = "1"
}

variable "invoker_members" {
  description = "List of IAM members allowed to invoke the private function, for example serviceAccount:pdf-extractor-caller@PROJECT_ID.iam.gserviceaccount.com."
  type        = list(string)
  default     = []
}
