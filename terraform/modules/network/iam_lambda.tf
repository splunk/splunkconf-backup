
data "template_file" "pol-splunk-route53-updatednsrecords-forlambda" {
  template = file("policy-aws/pol-splunk-route53-updatednsrecords-forlambda.json.tpl")

  vars = {
    zone-id         = aws_route53_zone.dnszone.id
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-route53-updatednsrecords-forlambda" {
  name_prefix = "splunkconf_route53_updatednsrecords_forlambda"
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-splunkconf-backup-${var.profile}-$(var.region-primary}-${var.splunktargetenv}"
  #}
  description = "Allow to update dns records from lambda at instance creation"
  #provider    = aws.region-primary
  policy      = data.template_file.pol-splunk-route53-updatednsrecords-forlambda.rendered
}

data "template_file" "pol-splunk-lambda-asg" {
  template = file("policy-aws/pol-splunk-asg.json.tpl")
}

resource "aws_iam_policy" "pol-splunk-lambda-asg" {
  description = "Permissions needed specific for ASG Lambda execution"
  #provider    = aws.region-primary
  policy      = data.template_file.pol-splunk-lambda-asg.rendered
}


data "template_file" "pol-splunk-cloudwatch-write" {
  template = file("policy-aws/cloudwatchwritepolicy.json")

}

resource "aws_iam_policy" "pol-splunk-cloudwatch-write" {
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-smartstore-${var.profile}-$(var.region-primary}-${var.splunktargetenv}"
  #}
  description = "Permissions needed for writing logs "
  #provider    = aws.region-primary
  policy      = data.template_file.pol-splunk-cloudwatch-write.rendered
}


