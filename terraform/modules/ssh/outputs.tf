

output "ssh_key_name" {
  description = "ssh key name"
  value       = aws_key_pair.splunk_ssh_key.key_name
}

output "secretsmanager_secretssh_version" {
  description = "secret manager version id for ssh priv key"
  value = aws_secretsmanager_secret_version.splunk_ssh_key.id
}

output "splunk_ssh_key_arn" {
  value = aws_secretsmanager_secret.splunk_ssh_key.id
  description = "splunk_ssh awssecretsmanager arn (to be used to get the key if authorized)"
}

output "splunk_ssh_key_ssm_arn" {
  value = aws_ssm_parameter.splunk_ssh_key.arn
  description = "splunk_ssh ssm  arn (to be used to get the key if authorized)"
}
