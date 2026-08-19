

output "splunkkmsarn" {
  description = "Splunk KMS ARN"
  value       = var.splunkencryption ? aws_kms_key.splunkkms.arn : null
}

output "splunkkmsid" {
  description = "Splunk KMS id"
  value       = var.splunkencryption ? aws_kms_key.splunkkms.id : null
}


