

output "ssh_key_name" {
  description = "ssh key name"
  value       = aws_key_pair.master-key.key_name
}
