# ---------- APIs ----------

resource "google_project_service" "cloudfunctions" {
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

# ---------- Service account ----------

resource "google_service_account" "extractor" {
  account_id   = local.sa_account_id
  display_name = "PDF Extractor (${local.environment})"
}

# Allow the Terraform runner to attach the runtime service account to the function.
resource "google_service_account_iam_member" "terraform_runner_act_as_extractor" {
  service_account_id = google_service_account.extractor.name
  role               = "roles/iam.serviceAccountUser"
  member             = trimspace(var.terraform_runner_member)
}

# Cloud Build may use the Compute Engine default service account for source builds.
resource "google_service_account_iam_member" "terraform_runner_act_as_build_sa" {
  service_account_id = "projects/${var.gcp_project_id}/serviceAccounts/${local.build_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = trimspace(var.terraform_runner_member)
}

resource "time_sleep" "wait_for_extract_sa_iam" {
  depends_on = [
    google_service_account_iam_member.terraform_runner_act_as_extractor,
    google_service_account_iam_member.terraform_runner_act_as_build_sa,
  ]

  create_duration = "60s"
}

# ---------- Stable suffixes ----------

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

# ---------- Source bucket ----------

resource "google_storage_bucket" "source" {
  name                        = local.bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.project_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# ---------- Source archive ----------

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/.build/function-source.zip"
}

resource "google_storage_bucket_object" "source" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function_source.output_path
}

# ---------- Cloud Function (2nd gen) ----------

resource "google_cloudfunctions2_function" "extractor" {
  name     = local.function_name
  location = var.gcp_region
  labels   = local.project_labels

  build_config {
    runtime     = "python312"
    entry_point = "extract_pdf"

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instance_count
    min_instance_count    = var.min_instance_count
    available_memory      = var.available_memory
    available_cpu         = var.available_cpu
    timeout_seconds       = var.timeout_seconds
    service_account_email = google_service_account.extractor.email
  }

  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild,
    google_project_service.run,
    google_project_service.artifactregistry,
    time_sleep.wait_for_extract_sa_iam,
  ]
}

# ---------- IAM: who can invoke ----------

resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = toset(var.invoker_members)

  project  = google_cloudfunctions2_function.extractor.project
  location = google_cloudfunctions2_function.extractor.location
  service  = google_cloudfunctions2_function.extractor.name
  role     = "roles/run.invoker"
  member   = each.value
}
