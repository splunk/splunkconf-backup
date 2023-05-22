data "template_file" "pol-splunk-ec2worker-secret" {
  template = file("policy-aws/pol-splunk-ec2worker-secret.json.tpl")
  vars = {
    secret          = aws_secretsmanager_secret.splunk_admin.arn
    secret2          = module.ssh.splunk_ssh_key_arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-ec2worker-secret" {
  name_prefix = "splunkconf_ec2workersecret_"
  # ... other configuration ...
  #name_prefix = local.name-prefix-pol-splunk-ec2
  description = "This policy include policy for Splunk EC2 Worker instances to access needed secret in AWS secrets"
  provider    = aws.region-primary
  policy      = data.template_file.pol-splunk-ec2worker-secret.rendered
}


resource "aws_iam_role" "role-splunk-worker" {
  name_prefix           = "role-splunk-worker"
  force_detach_policies = true
  description           = "iam role for splunk worker"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_role_policy_attachment" "worker-attach-splunk-ec2worker-secret" {
  #name       = "worker-attach-splunk-ec2worker-secret"
  role       = aws_iam_role.role-splunk-worker.name
  policy_arn = aws_iam_policy.pol-splunk-ec2worker-secret.arn
}

