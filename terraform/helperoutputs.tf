
locals {
  helper-getmycredentials = "./getmycredentials.sh ${var.region-primary} ${aws_secretsmanager_secret.splunk_admin.id} ${module.ssh.splunk_ssh_key_arn}"
}

output "helper-getmycredentials" {
  value       = local.helper-getmycredentials
  description = "command to run to get credentials (if authorized)"
}
