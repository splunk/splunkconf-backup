#Lambda function

resource "aws_iam_role" "role-splunk-lambda-route53-asg-tag" {
  name                  = "role-splunk-lambda-route53-asg-tag"
  force_detach_policies = true
  description           = "iam role for splunk lambda lambda-route53-asg-tag"
  assume_role_policy    = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-lambda-route53-asg-tag_profile" {
  name = "role-splunk-lambda-route53-asg-tag_profile"
  role = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
}

resource "aws_iam_policy_attachment" "lambda-route53-asg-tag-attach-splunk-splunkconf-backup" {
  name       = "lambda-route53-asg-tag-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "lambda-route53-asg-tag-attach-splunk-route53-updatednsrecords" {
  name       = "ds-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "lambda-route53-asg-tag--attach-splunk-ec2" {
  name       = "ds-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

data "archive_file" "zip_lambda_asg_updateroute53_tag" {
  type        = "zip"
  output_path = "lambda/lambda_asg_updateroute53_tag.zip"
  source {
    content  = file("lambda/lambda_asg_updateroute53_tag.py")
    filename = "lambda_asg_updateroute53_tag.py"
  }
}

resource "aws_lambda_function" "lambda_update-route53-tag" {
  filename         = data.archive_file.zip_lambda_asg_updateroute53_tag.output_path
  source_code_hash = data.archive_file.zip_lambda_asg_updateroute53_tag.output_base64sha256
  function_name    = "lambda_function.py"
  handler          = "lambda_handler"
  role             = aws_iam_role.role-splunk-lambda-route53-asg-tag
  runtime          = "python3.9"
}


