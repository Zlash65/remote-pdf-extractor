output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.remote_pdf_extractor.function_name
}

output "function_url" {
  description = "Lambda Function URL"
  value       = aws_lambda_function_url.remote_pdf_extractor.function_url
}
