# ********************* DS *******************
resource "aws_iam_role" "role-splunk-ds" {
  name_prefix           = "role-splunk-ds-"
  force_detach_policies = true
  description           = "iam role for splunk ds"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ds_profile" {
  name_prefix = "role-splunk-ds_profile"
  role        = aws_iam_role.role-splunk-ds.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ds-attach-splunk-splunkconf-backup" {
  #name       = "ds-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-ds.name
  #roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ds-attach-splunk-route53-updatednsrecords" {
  #name       = "ds-attach-splunk-route53-updatednsrecords"
  role = aws_iam_role.role-splunk-ds.name
  #roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ds-attach-splunk-ec2" {
  #name       = "ds-attach-splunk-ec2"
  role = aws_iam_role.role-splunk-ds.name
  #roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ds-attach-splunk-writesecret" {
  #name       = "ds-attach-splunk-ec2"
  role = aws_iam_role.role-splunk-ds.name
  #roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

#resource "aws_iam_role_policy_attachment" "ds-attach-ssm-managedinstance" {
##  name       = "ds-attach-ssm-managedinstance"
#  role      = aws_iam_role.role-splunk-ds.name
##  roles      = [aws_iam_role.role-splunk-ds.name]
#  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#  provider = aws.region-primary
#}

# this is used only when splunkdsenableworker is true
# todo : make conditional ?
resource "aws_iam_role_policy_attachment" "ds-attach-splunk-ec2worker-secret" {
  #name       = "worker-attach-splunk-ec2worker-secret"
  role       = aws_iam_role.role-splunk-ds.name
  policy_arn = aws_iam_policy.pol-splunk-ec2worker-secret.arn
}


resource "aws_security_group_rule" "ds_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "ds_from_worker_ssh" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-worker.id
  description              = "allow SSH connection from worker host"
}

resource "aws_security_group_rule" "ds_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "ds_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-ds.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ds_from_splunkadmin-networks_webui" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "ds_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-ds.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ds_from_all_icmp" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ds_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ds_from_mc_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_sh_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_cm_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_hf_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_iuf_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_networks_8089" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = setunion(var.ds-in-allowed-networks)
  description       = "allow DS comm from authorized networks"
}

resource "aws_security_group_rule" "ds_from_lbds_8089" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-lbds.id
  description              = "allow DS ELB to reach DS REST API port"
}

#resource "aws_security_group_rule" "ds_from_networks_8089" {
#  security_group_id = aws_security_group.splunk-ds.id
#  type              = "ingress"
#  from_port         = 8089
#  to_port           = 8089
#  protocol          = "tcp"
#  cidr_blocks       = ["127.0.0.19/32"]
#  description       = "allow connect to instance on mgt port (rest api)"
#}

#resource "aws_security_group_rule" "ds_from_networks_ipv6_8089" {
#  security_group_id = aws_security_group.splunk-ds.id
#  type              = "ingress"
#  from_port         = 8089
#  to_port           = 8089
#  protocol          = "tcp"
#  ipv6_cidr_blocks  = ["::1/128"]
#  description       = "allow connect to instance on mgt port (rest api)"
#}

resource "aws_autoscaling_group" "autoscaling-splunk-ds" {
  provider = aws.region-primary
  name_prefix         = "asg-splunk-ds-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  # automatically set to 0 is ds-enabled if set to false 
  # allow to reduce cost when not used (like for tests but still want all the AWS config created) 
  desired_capacity    = local.ds-nb
  max_size            = local.ds-nb
  min_size            = local.ds-nb
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-ds.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-ds
      }
    }
  }
  tag {
    key                 = "Type"
    value               = "Splunk"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnszone"
    value               = var.dns-zone-name
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsnames"
    value               = var.ds
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  target_group_arns = [aws_alb_target_group.ds.id]

  #depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy]
  depends_on = [null_resource.bucket_sync, aws_secretsmanager_secret.splunk_admin]
}

resource "aws_launch_template" "splunk-ds" {
  #name          = "splunk-ds"
  name_prefix   = "splunk-ds-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-ds
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  #  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.role-splunk-ds_profile.name
    #name = "role-splunk-ds_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = ( var.ds-enableworker ? [aws_security_group.splunk-outbound.id, aws_security_group.splunk-ds.id,aws_security_group.splunk-worker.id] : [aws_security_group.splunk-outbound.id, aws_security_group.splunk-ds.id])
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.ds
      splunkinstanceType    = var.ds
      splunks3backupbucket  = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket    = aws_s3_bucket.s3_data.id
      splunkdnszone         = var.dns-zone-name
      splunkdnsmode         = "lambda"
      splunkorg             = var.splunkorg
      splunktargetenv       = var.splunktargetenv
      # for multids , we need to deploy by tar in that case otherwise we use the value in splunktargetbinary
      splunktargetbinary    = ( var.dsnb >1 ? var.splunktar : var.splunktargetbinary )
      splunktargetcm        = "${local.dns-prefix}${var.cm}"
      splunktargetlm        = "${local.dns-prefix}${var.lm}"
      splunktargetds        = "${local.dns-prefix}${var.ds}"
      splunkcloudmode       = var.splunkcloudmode
      splunkosupdatemode    = var.splunkosupdatemode
      splunkconnectedmode   = var.splunkconnectedmode
      splunkacceptlicense   = var.splunkacceptlicense
      splunkbackupdebug     = var.splunkbackupdebug
      # if equal to 1 then disable multids automatically
      splunkdsnb         = var.dsnb
      splunkpwdinit         = var.splunkpwdinit
      splunkpwdarn          = aws_secretsmanager_secret.splunk_admin.id
      splunkenableworker    = ( var.ds-enableworker ? "1" : "0" )
      splunkpostextrasyncdir = var.splunkpostextrasyncdir
      splunkpostextracommand = var.splunkpostextracommand
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}

# DS ELB in front

resource "aws_security_group" "splunk-lb-ds-outbound" {
  name_prefix = "splunk-lb-ds-outbound-"
  description = "Outbound Security group for ELB DS"
  vpc_id      = local.master_vpc_id
  tags = {    
    Name = "splunk"
  }
}

resource "aws_security_group_rule" "lb_outbound_ds" {
  security_group_id        = aws_security_group.splunk-lb-ds-outbound.id
  type                     = "egress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description              = "allow outbound traffic for REST API port to DS"
}
  
resource "aws_security_group" "splunk-lbds" {
  name_prefix        = "splunk-lbds-"
  description = "Security group for Splunk LB DS"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-lbds"
  }
}

resource "aws_security_group_rule" "lbds_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbds.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbds_from_networks_8089" {
  security_group_id = aws_security_group.splunk-lbds.id
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = setunion(var.ds-in-allowed-networks)
  description       = "allow DS comm from authorized networks to LB DS"
}


resource "aws_alb_target_group" "ds" {
  name_prefix                   = "ds-"
  port                          = 8089
  protocol                      = "HTTPS"
  vpc_id                        = local.master_vpc_id
  load_balancing_algorithm_type = "round_robin"
  slow_start                    = 30
  # FIXME adapt for DS
  health_check {
    path                = "/" 
    port                = 8089
    protocol            = "HTTPS"
    healthy_threshold   = 3
    unhealthy_threshold = 2 
    timeout             = 25
    interval            = 30
  #  # {"text":"HEC is healthy","code":17}
  #  # return code 200
    matcher = "200" 
  }
} 


resource "aws_lb" "ds" {
  count = var.use_elb_ds ? 1 : 0
  name_prefix        = "ds"
  load_balancer_type = "application"
  drop_invalid_header_fields = true
  security_groups    = [aws_security_group.splunk-lb-ds-outbound.id, aws_security_group.splunk-lbds.id]
  #subnets            = [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id]
  subnets            = (local.use-elb-private-ds == "false" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  internal = local.use-elb-private-ds
  # Tracks HTTP Requests
  access_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbds"
    enabled = true
  }
  # Tracks TCP/TLS Connections (ALB only)
  connection_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbdscon"
    enabled = true
  }
  # Critical: Ensure the policy is attached before the LB tries to verify access
  depends_on = [
    aws_s3_bucket_policy.allow_access_for_lb_logs
  ]
}

# This create a alias which point on ELB when available so we can use a pretty name
# the same name is also included in the certificate request
resource "aws_route53_record" "dslb" {
  zone_id = module.network.dnszone_id
  name    = "${var.lbds}.${var.dns-zone-name}"
  type    = "A"

  alias {
    name                   = aws_lb.ds[0].dns_name
    zone_id                = aws_lb.ds[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_alb_listener" "ds" {
  count             = var.use_elb_ds ? 1 : 0
  load_balancer_arn = aws_lb.ds[0].arn
  port              = 8089
  # change here for HTTPS
  protocol = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn = aws_acm_certificate.acm_certificate_elb_ds.arn

  #default_action {
  #  target_group_arn = aws_alb_target_group.ds.arn
  #  type             = "forward"
  #}
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Are you lost ?"
      status_code  = "404"
    }
  }
}

# specific REST API part for DC-DS comm
resource "aws_alb_listener_rule" "rule_ds" {
 listener_arn = aws_alb_listener.ds[0].arn
 priority     = 60

 action {
   type             = "forward"
   target_group_arn = aws_alb_target_group.ds.arn
 }

 condition {
   path_pattern {
     values = ["/services/broker/connect/*","/services/broker/channel/subscribe/*","/services/broker/phonehome/*","/services/streams/deployment*"]
   }
 }
 condition {
   http_request_method {
     values = ["POST"]
  }
 }
}

resource "aws_acm_certificate" "acm_certificate_elb_ds" {
  domain_name       = "${var.lbds}.${var.dns-zone-name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_route53_record_elb_ds" {
  #count   = var.create_elb_hec_certificate ? 1 : 0
  #for dvo in aws_acm_certificate.acm_certificate_elb_hec[*].domain_validation_options : dvo.domain_name => {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate_elb_ds.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name 
  records         = [each.value.record]
  ttl             = 60  
  type            = each.value.type
  #name    = aws_acm_certificate.acm_certificate_elb_hec.domain_validation_options.0.resource_record_name
  #type    = aws_acm_certificate.acm_certificate_elb_hec.domain_validation_options.0.resource_record_type
  zone_id = module.network.dnszone_id
  #records = aws_acm_certificate.acm_certificate_elb_hec.domain_validation_options.0.resource_record_value
}

resource "aws_acm_certificate_validation" "acm_certificate_validation_elb_ds" {
  #  count                   = var.create_elb_hec_certificate ? 1 : 0
  certificate_arn = aws_acm_certificate.acm_certificate_elb_ds.arn
  # validation_record_fqdns = [
  #aws_route53_record.validation_route53_record_elb_hec.*.fqdn,
  #]
  validation_record_fqdns = [for record in aws_route53_record.validation_route53_record_elb_ds : record.fqdn]
} 
 
# WAF additional protection

resource "aws_wafv2_web_acl" "lbds" {
  name  = "wafds"
  scope = "REGIONAL"

  default_action {
    allow {
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAF_Common_Protections"
    sampled_requests_enabled   = true
  }

 rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 0
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "SizeRestrictions_BODY"
        }

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "CrossSiteScripting_BODY"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 1
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 2
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 3
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            allow {}
          }

          name = "HostingProviderIPList"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesUnixRuleSet"
    priority = 5
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesUnixRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesUnixRuleSet"
      sampled_requests_enabled   = true
    }
  }

}

resource "aws_cloudwatch_log_group" "lbds" {
  name_prefix       = "aws-waf-logs-lbds"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "lbds" {
  log_destination_configs = [aws_cloudwatch_log_group.lbds.arn]
  resource_arn            = aws_wafv2_web_acl.lbds.arn
  depends_on = [
    aws_wafv2_web_acl.lbds,
    aws_cloudwatch_log_group.lbds
  ]
}

resource "aws_wafv2_web_acl_association" "lbds" {
  resource_arn = aws_lb.ds[0].arn
  web_acl_arn  = aws_wafv2_web_acl.lbds.arn
  depends_on = [
    aws_wafv2_web_acl.lbds,
    aws_cloudwatch_log_group.lbds
  ]
}












output "ds-elb-dns-name" {
  value = one(aws_lb.ds[*].dns_name)
  description = "DS ELB dns name"
}


output "ds-name-to-reach" {
  value = local.ds
  description = "ds short name either direct or via lb is enabled"
}

output "ds-dns-name" {
  value       = local.ds-dns-name
  description = "ds dns name (private ip)"
}

output "ds-dns-name-ext" {
  value       = var.associate_public_ip ? "${local.dns-prefix}${var.ds}-ext.${var.dns-zone-name}" : "disabled"
  description = "ds ext dns name (pub ip)"
}

output "ds-url" {
  value       = var.associate_public_ip ? "https://${local.dns-prefix}${var.ds}-ext.${var.dns-zone-name}:8000" : "https://${local.dns-prefix}${var.ds}.${var.dns-zone-name}:8000"
  description = "ds url"
}

output "use-elb-private-ds" {
  value       = local.use-elb-private-ds
  description = "local.use-elb-private-ds"
}

output "ds-sshconnection" {
  value       = var.associate_public_ip ? "ssh -i mykey-${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.ds}-ext.${var.dns-zone-name}" : "ssh -i mykey-${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.ds}.${var.dns-zone-name}"
  description = "ds ssh connection"
}

