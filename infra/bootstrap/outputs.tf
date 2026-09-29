output "state_bucket" {
  description = "Bucket S3 (en LocalStack) que guarda el estado de infra/local."
  value       = aws_s3_bucket.state.id
}
