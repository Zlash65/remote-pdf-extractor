locals {
  workspace_name = trimspace(var.TFC_WORKSPACE_NAME) != "" ? trimspace(var.TFC_WORKSPACE_NAME) : terraform.workspace

  environment = trimspace(var.environment) != "" ? trimspace(var.environment) : (
    local.workspace_name != "default" ? regex("[^-]+$", local.workspace_name) : "shared"
  )

  resource_name_prefix = trimspace(var.resource_name_prefix) != "" ? trimspace(var.resource_name_prefix) : (
    local.workspace_name != "default" && can(regex("^.+-.+$", local.workspace_name)) ? regexreplace(local.workspace_name, "-[^-]+$", "") : "pdf-extractor"
  )

  function_name      = "${local.resource_name_prefix}-${local.environment}"
  bucket_name_prefix = "${local.resource_name_prefix}-source-${local.environment}"
  bucket_name        = "${local.bucket_name_prefix}-${random_id.bucket_suffix.hex}"
  sa_account_id      = "${local.resource_name_prefix}-${local.environment}"
  build_sa_email     = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  project_labels = merge(
    {
      environment = local.environment
      terraform   = "true"
      team        = "devops"
    },
    var.labels,
  )
}
