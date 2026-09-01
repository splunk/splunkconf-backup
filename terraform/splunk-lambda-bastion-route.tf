# Lambda + EventBridge automation for bastion NAT instance default route management.
# Active only when use_nat_gateway = false (bastion-as-NAT test mode).

data "aws_caller_identity" "bastion_route_lambda" {
  count = local.enable_lambda_bastion_route ? 1 : 0
}

data "aws_region" "bastion_route_lambda" {
  count = local.enable_lambda_bastion_route ? 1 : 0
}

resource "aws_iam_role" "role-splunk-lambda-bastion-route" {
  count                 = local.enable_lambda_bastion_route ? 1 : 0
  name_prefix           = "role-splunk-lambda-bastion-route"
  force_detach_policies = true
  description           = "iam role for splunk lambda bastion route updater"
  assume_role_policy    = file("policy-aws/assumerolepolicy-lambda.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_policy" "pol-splunk-lambda-bastion-route" {
  count       = local.enable_lambda_bastion_route ? 1 : 0
  name_prefix = "splunkconf_lambda_bastion_route"
  description = "Allow Lambda to manage private default route via bastion ENI"
  policy = templatefile(
    "policy-aws/pol-splunk-lambda-bastion-route.json.tpl",
    {
      region         = data.aws_region.bastion_route_lambda[0].name
      account_id     = data.aws_caller_identity.bastion_route_lambda[0].account_id
      route_table_id = aws_route_table.private_route_instancegw[0].id
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda-bastion-route-attach-policy" {
  count      = local.enable_lambda_bastion_route ? 1 : 0
  role       = aws_iam_role.role-splunk-lambda-bastion-route[0].name
  policy_arn = aws_iam_policy.pol-splunk-lambda-bastion-route[0].arn
}

resource "aws_iam_policy" "pol-splunk-lambda-bastion-route-logging" {
  count       = local.enable_lambda_bastion_route ? 1 : 0
  name_prefix = "splunkconf_lambda_bastion_route_logging"
  description = "CloudWatch logging for bastion route Lambda"
  policy      = file("policy-aws/cloudwatchwritepolicy.json")
}

resource "aws_iam_role_policy_attachment" "lambda-bastion-route-attach-cloudwatch-write" {
  count      = local.enable_lambda_bastion_route ? 1 : 0
  role       = aws_iam_role.role-splunk-lambda-bastion-route[0].name
  policy_arn = aws_iam_policy.pol-splunk-lambda-bastion-route-logging[0].arn
}

data "archive_file" "zip_lambda_bastion_update_route" {
  count       = local.enable_lambda_bastion_route ? 1 : 0
  type        = "zip"
  output_path = "lambda/lambda_bastion_update_route.zip"
  source {
    content  = file("lambda/lambda_bastion_update_route.py")
    filename = "lambda_bastion_update_route.py"
  }
}

# CloudWatch Logs provide sufficient observability; X-Ray tracing intentionally not enabled.
# nosemgrep: tools.semgrep.rules.splunk_custom.terraform.aws.security.aws-lambda-x-ray-tracing-not-active
resource "aws_lambda_function" "lambda_bastion_update_route" {
  count            = local.enable_lambda_bastion_route ? 1 : 0
  filename         = data.archive_file.zip_lambda_bastion_update_route[0].output_path
  source_code_hash = data.archive_file.zip_lambda_bastion_update_route[0].output_base64sha256
  function_name    = "aws_lambda_bastion_update_route"
  handler          = "lambda_bastion_update_route.lambda_handler"
  role             = aws_iam_role.role-splunk-lambda-bastion-route[0].arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  timeout          = 60

  environment {
    variables = {
      ROUTE_TABLE_ID   = aws_route_table.private_route_instancegw[0].id
      BASTION_ASG_NAME = "asg-splunk-bastion"
      DESTINATION_CIDR = "0.0.0.0/0"
    }
  }
}

resource "aws_cloudwatch_log_group" "splunkconf_bastion_route_logging" {
  count             = local.enable_lambda_bastion_route ? 1 : 0
  name_prefix       = "/aws/lambda/aws_lambda_bastion_update_route"
  retention_in_days = 14
  kms_key_id        = local.splunkkmsarn
}

resource "aws_cloudwatch_event_rule" "bastion_asg_route" {
  count       = local.enable_lambda_bastion_route ? 1 : 0
  name_prefix = "capture-bastion-asg-route"
  description = "Capture bastion ASG launch/terminate events for private route updates"

  event_pattern = <<EOF
{
  "detail-type": [
    "EC2 Instance Launch Successful",
    "EC2 Instance Terminate Successful"
  ],
  "source": [
    "aws.autoscaling"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "asg-splunk-bastion"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda_bastion_route" {
  count     = local.enable_lambda_bastion_route ? 1 : 0
  rule      = aws_cloudwatch_event_rule.bastion_asg_route[0].name
  target_id = "SendToLambdaBastionRoute"
  arn       = aws_lambda_function.lambda_bastion_update_route[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_bastion_route" {
  count         = local.enable_lambda_bastion_route ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchBastionRoute"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_bastion_update_route[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bastion_asg_route[0].arn
}

# Delay Lambda destroy so terminate events can delete the runtime-managed route first.
resource "time_sleep" "wait_bastion_route_lambda_destroy" {
  count            = local.enable_lambda_bastion_route ? 1 : 0
  destroy_duration = "1m"
  depends_on = [
    aws_lambda_function.lambda_bastion_update_route[0],
    aws_cloudwatch_event_rule.bastion_asg_route[0],
    aws_cloudwatch_event_target.lambda_bastion_route[0],
    aws_lambda_permission.allow_cloudwatch_bastion_route[0],
    aws_iam_role_policy_attachment.lambda-bastion-route-attach-policy[0],
    aws_iam_role_policy_attachment.lambda-bastion-route-attach-cloudwatch-write[0],
    aws_cloudwatch_log_group.splunkconf_bastion_route_logging[0],
  ]
}
