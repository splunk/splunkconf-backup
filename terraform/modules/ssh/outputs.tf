

output "ssh_key_name" {
  description = "ssh key name"
  value       = aws_key_pair.mykey.key_name
}

output "secretsmanager_secretssh" {
  description = "secret manager id for ssh priv key"
  value = aws_secretsmanager_secret.mykey.id
}

output "secretsmanager_secretssh_version" {
  description = "secret manager version id for ssh priv key"
  value = aws_secretsmanager_secret_version.mykey.id
}
