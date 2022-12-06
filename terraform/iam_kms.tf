data "template_file" "pol-splunk-kms" {
  template = file("policy-aws/pol-splunk-kms.json.tpl")

  vars = {
    kmsarn = data.terraform_remote_state.kms.outputs.splunkkmsarn
    #kmsarn          = aws_kms_key.splunkkms.arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-kms" {
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-smartstore-${var.profile}-$(var.region-primary}-${var.splunktargetenv}"
  #}
  description = "Permissions needed for KMS"
  provider    = aws.region-primary
  policy      = data.template_file.pol-splunk-kms.rendered
}


