
# ******************** IDX ********************

resource "aws_iam_role" "role-splunk-idx" {
  name_prefix           = "role-splunk-idx"
  force_detach_policies = true
  description           = "iam role for splunk idx"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-idx_profile" {
  name_prefix     = "role-splunk-idx_profile"
  role            = aws_iam_role.role-splunk-idx.name
  provider        = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-splunk-splunkconf-backup" {
  #name       = "idx-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-idx.name
  #roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-splunk-route53-updatednsrecords" {
  #name       = "idx-attach-splunk-route53-updatednsrecords"
  role = aws_iam_role.role-splunk-idx.name
  #roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-splunk-ec2" {
  #name       = "idx-attach-splunk-ec2"
  role = aws_iam_role.role-splunk-idx.name
  #roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-splunk-writesecret" {
  role = aws_iam_role.role-splunk-idx.name
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-splunk-smartstore" {
  #name       = "idx-attach-splunk-smartstore"
  role = aws_iam_role.role-splunk-idx.name
  #roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-smartstore.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "idx-attach-ssm-managedinstance" {
  #name       = "idx-attach-ssm-managedinstance"
  role = aws_iam_role.role-splunk-idx.name
  #roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# see https://discuss.hashicorp.com/t/discussion-of-aws-security-group-rules-for-absolute-management-while-avoiding-cyclical-dependencies/9647
# security group are referencing each other in a splunk deployment creating a cycling dependency (still a issue with terraform 0.13.5 at the least)
# until another solution exist (could be a future terraform version that automagically completelly this ?) , we have to use multiple levels with group rules , see link above

resource "aws_security_group_rule" "idx_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "idx_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "idx_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-idx.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "idx_from_idx_8089" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  self              = true
  description       = "allow IDX to connect to other IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_cm_8089" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description              = "allow CM to connect to IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_mc_8089" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_sh_8089" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description              = "allow SH to connect to IDX on mgt port for searches"
}

resource "aws_security_group_rule" "idx_from_all_icmp" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

#resource "aws_security_group_rule" "idx_from_all_icmpv6" {
#  security_group_id = aws_security_group.splunk-idx.id
#  type              = "ingress"
#  from_port         = -1
#  to_port           = -1
#  protocol          = "icmpv6"
#  ipv6_cidr_blocks  = ["::/0"]
#  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
#}

resource "aws_security_group_rule" "idx_from_lbhec_8088" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 8088
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-lbhec.id
  description              = "allow ELB to send HEC to IDX"
}

resource "aws_security_group_rule" "idx_from_networks_8088" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks)
  description       = "allow IDX to receive hec from authorized networks"
}

resource "aws_security_group_rule" "idx_from_idx_9887" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = 9887
  to_port           = 9887
  protocol          = "tcp"
  self              = true
  description       = "allow IDX to connect to other IDX for inter cluster replication"
}

resource "aws_security_group_rule" "idx_from_mc_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_sh_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_ds_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_cm_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_lm_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-lm.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_hf_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_iuf_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_ihf_log" {
  security_group_id        = aws_security_group.splunk-idx.id
  type                     = "ingress"
  from_port                = 9997
  to_port                  = 9999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ihf.id
  description              = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_networks_log" {
  security_group_id = aws_security_group.splunk-idx.id
  type              = "ingress"
  from_port         = 9997
  to_port           = 9999
  protocol          = "tcp"
  cidr_blocks       = setunion(var.s2s-in-allowed-networks)
  description       = "allow to receive logs via S2S (remote networks)"
}

# OUTBOUND 

# LB

resource "aws_security_group" "splunk-lb-hecidx-outbound" {
  name_prefix = "splunk-lb-hecidx-outbound"
  description = "Outbound Security group for ELB HEC to IDX"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk"
  }
}

resource "aws_security_group_rule" "lb_outbound_hecidx" {
  security_group_id        = aws_security_group.splunk-lb-hecidx-outbound.id
  type                     = "egress"
  from_port                = 8088
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-idx.id
  description              = "allow outbound traffic for hec to IDX"
}

# ASG
resource "aws_autoscaling_group" "autoscaling-splunk-idx" {
  #name                = "asg-splunk-idx"
  name_prefix          = "asg-splunk-idx-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  desired_capacity    = var.idx-nb
  max_size            = var.idx-nb
  min_size            = var.idx-nb
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-idx.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-indexer
      }
    }
  }
  #  provisioner "local-exec" {
  #    command = "./build-idx-scripts.sh ${local.instance-type-indexer}"
  #  }
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
    value               = var.idxdnsnames
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }
  default_cooldown = var.idxasg_cooldown

  target_group_arns = [aws_alb_target_group.idxhec.id]
  depends_on        = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-idx" {
  #name          = "splunk-idx"
  name_prefix    = "splunk-idx-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = local.instance-type-indexer
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-idx-a
      volume_type = "gp3"
    }
  }
  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size = var.disk-size-idx-b
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  #  vpc_security_group_ids = [aws_security_group.splunk-idx.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.role-splunk-idx_profile.name
    #name = "role-splunk-idx_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-idx.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = "idx"
      splunkinstanceType    = "idx"
      splunks3backupbucket  = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket    = aws_s3_bucket.s3_data.id
      splunkdnszone         = var.dns-zone-name
      splunkdnsmode         = "lambda"
      splunkorg             = var.splunkorg
      splunktargetenv       = var.splunktargetenv
      splunktargetbinary    = var.splunktargetbinary
      splunktargetcm        = "${local.dns-prefix}${var.cm}"
      splunktargetlm        = "${local.dns-prefix}${var.lm}"
      splunktargetds        = "${local.dns-prefix}${var.ds}"
      # IDX special case
      splunkcloudmode     = "3"
      splunkosupdatemode  = var.splunkosupdatemode
      splunkconnectedmode = var.splunkconnectedmode
      splunkacceptlicense = var.splunkacceptlicense
      splunkenableunifiedpartition = var.splunkenableunifiedpartition
      splunksmartstoresitenumber = var.splunksmartstoresitenumber
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}

# ***************** LB HEC **********************
resource "aws_security_group" "splunk-lbhec" {
  name        = "splunk-lbhec"
  description = "Security group for Splunk LB for HEC to idx"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-lbhec"
  }
}

resource "aws_security_group_rule" "lbhec_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

#resource "aws_security_group_rule" "lbhec_from_all_icmpv6" {
#  security_group_id = aws_security_group.splunk-lbhec.id
#  type              = "ingress"
#  from_port         = -1
#  to_port           = -1
#  protocol          = "icmpv6"
#  ipv6_cidr_blocks  = ["::/0"]
#  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
#}

resource "aws_security_group_rule" "lbhec_from_networks_8088" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks,var.hec-in-allowed-firehose-networks)
  description       = "allow hec from authorized networks"
}

resource "aws_alb_target_group" "idxhec" {
  name_prefix                   = "hec-"
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

resource "aws_alb_target_group" "idxhec-ack" {
  name_prefix                   = "heca-"
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

resource "aws_lb" "idxhec-noack" {
  count    = var.use_elb ? 1 : 0
  #count = var.enable-idx-hecelb ? 1: 0
  name               = "idxhec-noack"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.splunk-lb-hecidx-outbound.id, aws_security_group.splunk-lbhec.id]
  subnets            = (local.use-elb-private == "false" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
}


resource "aws_lb" "idxhec-ack" {
  count    = var.use_elb_ack ? 1 : 0
  #count = var.enable-idx-hecelb ? 1: 0
  name               = "idxhec-ack"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.splunk-lb-hecidx-outbound.id, aws_security_group.splunk-lbhec.id]
  subnets            = (local.use-elb-private == "false" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
}


resource "aws_alb_listener" "idxhec-noack" {
  count    = var.use_elb ? 1 : 0
  load_balancer_arn = aws_lb.idxhec-noack[0].arn
  port              = 8088
  # change here for HTTPS
  protocol = "HTTPS"
  certificate_arn = aws_acm_certificate_validation.acm_certificate_validation_elb_hec.certificate_arn
  default_action {
    target_group_arn = aws_alb_target_group.idxhec.arn
    type             = "forward"
  }
}

resource "aws_alb_listener" "idxhec-ack" {
  count    = var.use_elb_ack ? 1 : 0
  load_balancer_arn = aws_lb.idxhec-ack[0].arn
  port              = 8088
  # change here for HTTPS
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.idxhec-ack.arn
    type             = "forward"
  }
}

resource "aws_acm_certificate" "acm_certificate_elb_hec" {
  #count = var.create_elb_hec_certificate ? 1 : 0
  domain_name               = var.dns-zone-name
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_route53_record_elb_hec" {
  #count   = var.create_elb_hec_certificate ? 1 : 0
    #for dvo in aws_acm_certificate.acm_certificate_elb_hec[*].domain_validation_options : dvo.domain_name => {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate_elb_hec.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "acm_certificate_validation_elb_hec" { 
#  count                   = var.create_elb_hec_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.acm_certificate_elb_hec.arn
 # validation_record_fqdns = [
 #aws_route53_record.validation_route53_record_elb_hec.*.fqdn,
 #]
  validation_record_fqdns = [for record in aws_route53_record.validation_route53_record_elb_hec : record.fqdn]
}

output "idx-dns-name" {
  value       = local.idx-dns-name
  description = "idx (single) dns name (private ip)"
}

output "idx-dns-names" {
  value       = "${local.dns-prefix}[${var.idxdnsnames}].${var.dns-zone-name}"
  description = "idx/inputs (multiples) dns name (private ip)"
}

output "idx-dns-name-ext" {
  value       = var.associate_public_ip ? "${local.dns-prefix}${var.idx}-ext.${var.dns-zone-name}" : "disabled"
  description = "idx (single) ext dns name (pub ip)"
} 

output "idx-dns-names-ext" {
  value       = var.associate_public_ip ? "${local.dns-prefix}${var.idxdnsnames}-ext.${var.dns-zone-name}" : "disabled"
  description = "idx/inputs (multiples) ext dns name (pub ip)"
} 

output "idx-sshconnection" {
  value       = var.associate_public_ip ? "ssh -i mykey${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.idx}-ext.${var.dns-zone-name}" : "ssh -i mykey${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.idx}.${var.dns-zone-name}"
  description = "idx ssh connection"
}
