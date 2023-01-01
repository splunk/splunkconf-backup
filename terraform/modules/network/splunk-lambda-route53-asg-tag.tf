#Lambda function

resource "aws_iam_role" "role-splunk-lambda-route53-asg-tag" {
  #provider              = aws.region-primary
  name_prefix           = "role-splunk-lambda-route53-asg-tags"
  force_detach_policies = true
  description           = "iam role for splunk lambda lambda-route53-asg-tag"
  assume_role_policy    = file("policy-aws/assumerolepolicy-lambda.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-lambda-route53-asg-tag_profile" {
  #provider = aws.region-primary
  name_prefix     = "role-splunk-lambda-route53-asg-tag_profile"
  role     = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
}

#resource "aws_iam_policy_attachment" "lambda-route53-asg-tag-attach-splunk-splunkconf-backup" {
#  name       = "lambda-route53-asg-tag-attach-splunk-splunkconf-backup"
#  roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
#  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
#}

resource "aws_iam_role_policy_attachment" "lambda-route53-asg-tag-attach-splunk-route53-updatednsrecords-forlambda" {
  #provider = aws.region-primary
  #name       = "lambda-attach-splunk-route53-updatednsrecords"
  #roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  role       = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords-forlambda.arn
}

#resource "aws_iam_role_policy_attachment" "lambda-route53-asg-tag-attach-splunk-ec2" {
#  provider = aws.region-primary
#  #name       = "lambda-attach-splunk-ec2"
#  #roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
#  role       = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
##   policy_arn = aws_iam_policy.pol-splunk-route53-ec2.arn
#}

resource "aws_iam_role_policy_attachment" "lambda-route53-asg-tag-attach-splunk-asg" {
  #provider = aws.region-primary
  #name       = "lambda-attach-splunk-asg"
  #roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  role       = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
  policy_arn = aws_iam_policy.pol-splunk-lambda-asg.arn
}

resource "aws_iam_role_policy_attachment" "lambda-route53-asg-tag-attach-assume-role" {
  #provider = aws.region-primary
  #name       = "lambda-attach-splunk-lambda"
  #roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  role       = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  #policy_arn = aws_iam_policy.pol-splunk-lambda.arn
}

resource "aws_iam_role_policy_attachment" "lambda-route53-asg-tag-attach-splunk-cloudwatch-write" {
  #provider = aws.region-primary
  #name       = "lambda-attach-splunk-logwrite"
  #roles      = [aws_iam_role.role-splunk-lambda-route53-asg-tag.name]
  role       = aws_iam_role.role-splunk-lambda-route53-asg-tag.name
  policy_arn = aws_iam_policy.pol-splunk-cloudwatch-write.arn
}

data "archive_file" "zip_lambda_asg_updateroute53_tag" {
  type        = "zip"
  output_path = local.output_path
  source {
    content  = file("lambda/lambda_asg_updateroute53_tag.py")
    filename = "lambda_asg_updateroute53_tag.py"
  }
}

# we get current time to add to function name
# this is to create different name 

resource "time_static" "lambda" {
} 


locals {
#    current_timestamp  = timestamp()
#    ti        = formatdate("YYYY-MM-DD-hh:mm:ss", local.current_timestamp)
#  function_name="aws_lambda_autoscale_route53_tags${time_static.lambda.rfc3339}"
#  handler="lambda_asg_updateroute53_tag${time_static.lambda.rfc3339}.lambda_handler"
#  output_path = "lambda/lambda_asg_updateroute53_tag${time_static.lambda.rfc3339}.zip"
  function_name="aws_lambda_autoscale_route53_tags"
  handler="lambda_asg_updateroute53_tag.lambda_handler"
  output_path = "lambda/lambda_asg_updateroute53_tag.zip"
}


resource "aws_lambda_function" "lambda_update-route53-tag" {
  #provider         = aws.region-primary
  filename         = data.archive_file.zip_lambda_asg_updateroute53_tag.output_path
  source_code_hash = data.archive_file.zip_lambda_asg_updateroute53_tag.output_base64sha256
  function_name    = local.function_name
  #function_name         = "lambda_handler"
  handler = local.handler
  role    = aws_iam_role.role-splunk-lambda-route53-asg-tag.arn
  runtime = "python3.9"
  timeout = 60
  # we need dns zone to be available before 
  depends_on = [aws_route53_zone.dnszone]
}

resource "aws_cloudwatch_log_group" "splunkconf_asg_logging" {
  #provider          = aws.region-primary
  name_prefix              = "/aws/lambda/lambda_update-route53-tag"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  #provider    = aws.region-primary
  name_prefix        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

#resource "aws_iam_role_policy_attachment" "lambda_logs" {
#  role       = aws_iam_role.iam_for_lambda.name
#  policy_arn = aws_iam_policy.lambda_logging.arn
#}

resource "aws_cloudwatch_event_rule" "asg" {
  #provider    = aws.region-primary
  name_prefix        = "capture-aws-asg"
  description = "Capture each AWS ASG events"

  event_pattern = <<EOF
{
  "detail-type": [
    "EC2 Instance Launch Successful",
    "EC2 Instance Terminate Successful",
    "EC2 Instance Launch Unsuccessful",
    "EC2 Instance Terminate Unsuccessful",
    "EC2 Instance-launch Lifecycle Action",
    "EC2 Instance-terminate Lifecycle Action"
  ],
  "source": [
    "aws.autoscaling"
  ]
}
EOF

}

resource "aws_cloudwatch_event_target" "lambda_route53asg" {
  #provider  = aws.region-primary
  rule      = aws_cloudwatch_event_rule.asg.name
  target_id = "SendTolambdaroute53asg"
  arn       = aws_lambda_function.lambda_update-route53-tag.arn
}

resource "aws_lambda_alias" "route53asg_alias" {
  #provider         = aws.region-primary
  name             = "route53asg"
  description      = "lambda route53 asg alias"
  function_name    = aws_lambda_function.lambda_update-route53-tag.function_name
  function_version = "$LATEST"
}


resource "aws_lambda_permission" "allow_cloudwatch_route53asg" {
  #provider      = aws.region-primary
  statement_id  = "AllowExecutionFromCloudWatchroute53asg"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_update-route53-tag.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg.arn
  #qualifier     = aws_lambda_alias.route53asg_alias.name
}

# this is used to not destroy lambda immediately after asg as we need some time for eventbridge event to fire the lambda that will remove dsn entries in route53
resource "time_sleep" "wait_asglambda_destroy" {
  # timer for lambda is currently 60s
  # high value for test only
  destroy_duration = "1m"
  depends_on       = [aws_lambda_function.lambda_update-route53-tag, aws_cloudwatch_event_rule.asg, aws_iam_role_policy_attachment.lambda-route53-asg-tag-attach-assume-role, aws_cloudwatch_log_group.splunkconf_asg_logging, aws_route_table.internet_route, aws_main_route_table_association.set-master-default-rt-assoc, aws_cloudwatch_event_target.lambda_route53asg, aws_iam_role_policy_attachment.lambda-route53-asg-tag-attach-splunk-route53-updatednsrecords-forlambda, aws_iam_policy.lambda_logging, aws_lambda_alias.route53asg_alias, aws_lambda_permission.allow_cloudwatch_route53asg, aws_iam_role_policy_attachment.lambda-route53-asg-tag-attach-splunk-cloudwatch-write, aws_iam_role_policy_attachment.lambda-route53-asg-tag-attach-splunk-asg]
}
