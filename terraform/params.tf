resource "aws_ssm_parameter" "splunkorg" {
  name        = "splunkorg"
  description = "Organisation"
  type        = "String"
  value       = var.splunkorg

  tags = {
    environment = var.splunktargetenv
  }
}
