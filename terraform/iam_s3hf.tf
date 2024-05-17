
# Commented as this currently error out with invalid policy from AWS when not set

resource "aws_iam_policy" "pol-splunk-s3-hf" {
  name_prefix = "splunkconf_s3_hf_"
  description = "Permissions needed for Splunk to access ${var.s3_bucket_1}/{var.s3_prefix_1}"
  provider    = aws.region-primary
#  policy      = templatefile(
#"policy-aws/pol-splunk-access-s3.json.tpl",
#{
#    s3_bucket       = var.s3_bucket_1
#    s3_prefix     = var.s3_prefix_1
#    profile         = var.profile
#    splunktargetenv = var.splunktargetenv
#  }
#)
 policy = "{ \"Version\": \"2012-10-17\", \"Statement\": [ ] } "

}

