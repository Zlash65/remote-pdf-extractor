output "function_url" {
  description = "The HTTPS URL of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.remote_pdf_extractor.url
}
