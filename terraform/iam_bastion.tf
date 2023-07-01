
#data "template_file" "pol-splunk-bastion" {
#  template = file("policy-aws/pol-splunk-bastion.json.tpl")
#  vars = {
#    s3_install      = aws_s3_bucket.s3_install.arn
#    profile         = var.profile
#    splunktargetenv = var.splunktargetenv
#  }
#}

resource "aws_iam_policy" "pol-splunk-bastion" {
  # ... other configuration ...
  #name_prefix = local.name-prefix-pol-splunk-bastion
  description = "This policy include shared policy for Splunk EC2 bastion instance"
  provider    = aws.region-primary
  policy      = templatefile(
"policy-aws/pol-splunk-bastion.json.tpl",
{
    s3_install      = aws_s3_bucket.s3_install.arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }



)
}

