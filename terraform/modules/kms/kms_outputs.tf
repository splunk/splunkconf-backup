

output "splunkkmsarn" {
  description = "Splunk KMS ARN"
  value = aws_kms_key.splunkkms.arn
}

output "splunkkmsid" {
  description = "Splunk KMS id"
  value = aws_kms_key.splunkkms.id
}


