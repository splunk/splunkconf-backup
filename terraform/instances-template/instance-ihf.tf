
# ******************** IHF ***********************

resource "aws_iam_role" "role-splunk-ihf" {
  name_prefix           = "role-splunk-ihf-"
  force_detach_policies = true
  description           = "iam role for splunk ihf"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ihf_profile" {
  name_prefix = "role-splunk-ihf_profile"
  role        = aws_iam_role.role-splunk-ihf.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-splunkconf-backup" {
  role = aws_iam_role.role-splunk-ihf.name
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-route53-updatednsrecords" {
  role       = aws_iam_role.role-splunk-ihf.name
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-ec2" {
  role       = aws_iam_role.role-splunk-ihf.name
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-writesecret" {
  role       = aws_iam_role.role-splunk-ihf.name
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

resource "aws_security_group_rule" "ihf_from_bastion_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-ihf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "ihf_from_worker_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-ihf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-worker.id
  description              = "allow SSH connection from worker host"
}
resource "aws_security_group_rule" "ihf_from_splunkadmin-networks_ssh" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

resource "aws_security_group_rule" "ihf_from_splunkadmin-networks_webui" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow WebUI connection from splunk admin networks"
}

#resource "aws_security_group_rule" "ihf_from_splunkadmin-networks-ipv6_ssh" { 
#  provider    = aws.region-primary
#  security_group_id = aws_security_group.splunk-ihf.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

#resource "aws_security_group_rule" "ihf_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-ihf.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ihf_from_all_icmp" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ihf_from_all_icmpv6" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ihf_from_mc_8089" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-ihf.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

# only when hf used as hec intermediate (instead of direct to idx via LB)
resource "aws_security_group_rule" "ihf_from_networks_8088" {
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks)
  description       = "allow to receive hec from authorized networks"
}

resource "aws_autoscaling_group" "autoscaling-splunk-ihf" {
  provider = aws.region-primary
  #name                = "asg-splunk-ihf"
  name_prefix         = "asg-splunk-ihf-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  desired_capacity    = var.ihf-nb
  max_size            = var.ihf-nb
  min_size            = var.ihf-nb
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-ihf.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-hf
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
    # use ihfnames here instead of ihf so we can publish multiple entries (as ihf is a single name)
    value               = var.ihfnames
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  #depends_on = [null_resource.bucket_sync, aws_autoscaling_group.autoscaling-splunk-bastion, aws_iam_role.role-splunk-ihf]
  depends_on = [null_resource.bucket_sync, aws_iam_role.role-splunk-ihf]
}

resource "aws_launch_template" "splunk-ihf" {
  provider = aws.region-primary
  #name          = "splunk-ihf"
  name_prefix   = "splunk-ihf-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-hf
      volume_type = "gp3"
      encrypted= local.splunkencryption
      # fixme : add iam for this
      #kms_key_id = local.splunkkmsarn
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = aws_iam_instance_profile.role-splunk-ihf_profile.name
    #name = "role-splunk-ihf_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-ihf.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.ihf
      splunkinstanceType    = var.ihf
      splunks3backupbucket  = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket    = aws_s3_bucket.s3_data.id
      splunkdnszone         = var.dns-zone-name
      splunkdnsmode         = "lambda"
      splunkorg             = var.splunkorg
      splunktargetenv       = var.splunktargetenv
      splunktargetbinary    = var.splunktargetbinary
      splunktargetcm        = var.cm
      splunktargetlm        = var.lm
      splunktargetds        = var.ds
      splunkcloudmode       = var.splunkcloudmode
      splunkosupdatemode    = var.splunkosupdatemode
      splunkconnectedmode   = var.splunkconnectedmode
      splunkacceptlicense   = var.splunkacceptlicense
      splunkbackupdebug     = var.splunkbackupdebug
      splunkpwdinit         = var.splunkpwdinit
      splunkpwdarn          = aws_secretsmanager_secret.splunk_admin.id
      splunkhostmodeos      = "ami"
      splunkhostmode        = "prefix"
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

# OUTBOUND

# LB
  
resource "aws_security_group" "splunk-lb-hecihf-outbound" {
  name_prefix = "splunk-lb-hecihf-outbound"
  description = "Outbound Security group for ELB HEC to IHF"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk"
  }
} 
  
resource "aws_security_group_rule" "lb_outbound_hecihf" {
  security_group_id        = aws_security_group.splunk-lb-hecihf-outbound.id
  type                     = "egress"
  from_port                = 8088
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ihf.id
  description              = "allow outbound traffic for hec to IHF"
}



# ***************** LB HEC **********************
resource "aws_security_group" "splunk-lbhecihf" {
  name        = "splunk-lbhecihf"
  description = "Security group for Splunk LB for HEC to ihf"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-lbhecihf"
  }
}

resource "aws_security_group_rule" "lbhecihf_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbhecihf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

#resource "aws_security_group_rule" "lbhecihf_from_all_icmpv6" {
#  security_group_id = aws_security_group.splunk-lbhecihf.id
#  type              = "ingress"
#  from_port         = -1
#  to_port           = -1
#  protocol          = "icmpv6"
#  ipv6_cidr_blocks  = ["::/0"]
#  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
#}

resource "aws_security_group_rule" "lbhecihf_from_networks_8088" {
  security_group_id = aws_security_group.splunk-lbhecihf.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks, var.hec-in-allowed-firehose-networks)
  description       = "allow hec from authorized networks"
}

resource "aws_alb_target_group" "ihfhec" {
  name_prefix                   = "ihec-"
  port                          = 8088
  protocol                      = var.hec_protocol
  vpc_id                        = local.master_vpc_id
  load_balancing_algorithm_type = "round_robin"
  slow_start                    = 30
  health_check {
    path                = "/services/collector/health/1.0"
    port                = 8088
    protocol            = var.hec_protocol
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 25
    interval            = 30
    # {"text":"HEC is healthy","code":17}
    # return code 200
    matcher = "200"
  }
}

resource "aws_alb_target_group" "ihfhec-ack" {
  name_prefix                   = "iheca-"
  port                          = 8088
  protocol                      = var.hec_protocol
  vpc_id                        = local.master_vpc_id
  load_balancing_algorithm_type = "round_robin"
  # important for ack to work correctly
  # alternate would be to rely on cookie
  stickiness {
    enabled = true
    type    = "lb_cookie"
  }
  slow_start = 30
  health_check {
    path                = "/services/collector/health/1.0"
    port                = 8088
    protocol            = var.hec_protocol
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 25
    interval            = 30
    # {"text":"HEC is healthy","code":17}
    # return code 200
    matcher = "200"
  }
}

resource "aws_lb" "ihfhec-noack" {
  count = var.use_elb ? 1 : 0
  #count = var.enable-ihf-hecelb ? 1: 0
  name               = "ihfhec-noack"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.splunk-lb-hecihf-outbound.id, aws_security_group.splunk-lbhecihf.id]
  subnets            = (local.use-elb-private == "false" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  drop_invalid_header_fields = true
  # Tracks HTTP Requests
  access_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbhecnoack"
    enabled = true
  }
  # Tracks TCP/TLS Connections (ALB only)
  connection_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbhecnoack"
    enabled = true
  }
  # Critical: Ensure the policy is attached before the LB tries to verify access
  depends_on = [
    aws_s3_bucket_policy.allow_access_for_lb_logs
  ]

}


resource "aws_lb" "ihfhec-ack" {
  count = var.use_elb_ack ? 1 : 0
  #count = var.enable-ihf-hecelb ? 1: 0
  name               = "ihfhec-ack"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.splunk-lb-hecihf-outbound.id, aws_security_group.splunk-lbhecihf.id]
  subnets            = (local.use-elb-private == "false" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  drop_invalid_header_fields = true
  # Tracks HTTP Requests
  access_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbhecack"
    enabled = true
  }
  # Tracks TCP/TLS Connections (ALB only)
  connection_logs {
    bucket  = aws_s3_bucket.s3_data.bucket
    prefix  = "log/lbhecack"
    enabled = true
  }
  # Critical: Ensure the policy is attached before the LB tries to verify access
  depends_on = [
    aws_s3_bucket_policy.allow_access_for_lb_logs
  ]
}


resource "aws_alb_listener" "idxhec-noack" {
  count             = var.use_elb ? 1 : 0
  load_balancer_arn = aws_lb.ihfhec-noack[0].arn
  port              = 8088
  # change here for HTTPS
  protocol        = "HTTPS"
  certificate_arn = aws_acm_certificate_validation.acm_certificate_validation_elb_hecihf.certificate_arn
  default_action {
    target_group_arn = aws_alb_target_group.ihfhec.arn
    type             = "forward"
  }
}



resource "aws_alb_listener" "ihfhec-ack" {
  count             = var.use_elb_ack ? 1 : 0
  load_balancer_arn = aws_lb.ihfhec-ack[0].arn
  port              = 8088
  # change here for HTTPS
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.ihfhec-ack.arn
    type             = "forward"
  }
}

resource "aws_acm_certificate" "acm_certificate_elb_hecihf" {
  #count = var.create_elb_hec_certificate ? 1 : 0
  domain_name       = var.dns-zone-name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_route53_record_elb_hecihf" {
  #count   = var.create_elb_hec_certificate ? 1 : 0
  #for dvo in aws_acm_certificate.acm_certificate_elb_hec[*].domain_validation_options : dvo.domain_name => {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate_elb_hecihf.domain_validation_options : dvo.domain_name => {
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
  #name    = aws_acm_certificate.acm_certificate_elb_hecihf.domain_validation_options.0.resource_record_name
  #type    = aws_acm_certificate.acm_certificate_elb_hecihf.domain_validation_options.0.resource_record_type
  zone_id = module.network.dnszone_id
  #records = aws_acm_certificate.acm_certificate_elb_hecihf.domain_validation_options.0.resource_record_value
}

resource "aws_acm_certificate_validation" "acm_certificate_validation_elb_hecihf" {
  #  count                   = var.create_elb_hec_certificate ? 1 : 0
  certificate_arn = aws_acm_certificate.acm_certificate_elb_hecihf.arn
  # validation_record_fqdns = [
  #aws_route53_record.validation_route53_record_elb_hec.*.fqdn,
  #]
  validation_record_fqdns = [for record in aws_route53_record.validation_route53_record_elb_hecihf : record.fqdn]
}

output "ihf-elb-ihfhec-noack-dns-name" {
  value = one(aws_lb.ihfhec-noack[*].dns_name)
  description = "ihf ELB HEC no ack dns name"
}

output "ihf-elb-ihfhec-ack-dns-name" {
  value = one(aws_lb.ihfhec-ack[*].dns_name)
  description = "ihf ELB HEC ack dns name"
}

output "ihf-dns-name" {
  value       = "${local.dns-prefix}${var.hf}.${var.dns-zone-name}"
  description = "hf dns name (private ip)"
}

output "ihf-dns-name-ext" {
  value       = "${local.dns-prefix}${var.ihf}-ext.${var.dns-zone-name}"
  description = "ihf dns name (pub ip) (if exist)"
} 

