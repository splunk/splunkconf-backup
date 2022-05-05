
# ******************** HF ***********************

resource "aws_iam_role" "role-splunk-hf" {
  name                  = "role-splunk-hf-3"
  force_detach_policies = true
  description           = "iam role for splunk hf"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-master

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-hf_profile" {
  name     = "role-splunk-hf_profile"
  role     = aws_iam_role.role-splunk-hf.name
  provider = aws.region-master
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-splunkconf-backup" {
  #name       = "hf-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-hf.name
  #roles      = [aws_iam_role.role-splunk-hf.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-master
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-route53-updatednsrecords" {
  #name       = "hf-attach-splunk-route53-updatednsrecords"
  #roles      = [aws_iam_role.role-splunk-hf.name]
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-master
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-ec2" {
  #name       = "hf-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-hf.name]
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-master
}

#resource "aws_iam_role_policy_attachment" "hf-attach-ssm-managedinstance" {
#  #name       = "hf-attach-ssm-managedinstance"
#  #roles      = [aws_iam_role.role-splunk-hf.name]
#  role      = aws_iam_role.role-splunk-hf.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#  provider    = aws.region-master
#}


resource "aws_security_group_rule" "hf_from_bastion_ssh" {
  provider                 = aws.region-master
  security_group_id        = aws_security_group.splunk-hf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "hf_from_splunkadmin-networks_ssh" {
  provider          = aws.region-master
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "hf_from_splunkadmin-networks-ipv6_ssh" { 
#  provider    = aws.region-master
#  security_group_id = aws_security_group.splunk-hf.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "hf_from_splunkadmin-networks_webui" {
  provider          = aws.region-master
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "hf_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-hf.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "hf_from_all_icmp" {
  provider          = aws.region-master
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_all_icmpv6" {
  provider          = aws.region-master
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_mc_8089" {
  provider                 = aws.region-master
  security_group_id        = aws_security_group.splunk-hf.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-hf" {
  provider            = aws.region-master
  name                = "asg-splunk-hf"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [aws_subnet.subnet_pub_1.id, aws_subnet.subnet_pub_2.id, aws_subnet.subnet_pub_3.id] : [aws_subnet.subnet_priv_1.id, aws_subnet.subnet_priv_2.id, aws_subnet.subnet_priv_3.id])
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-hf.id
        version            = "$Latest"
      }
      override {
        instance_type = "t3a.nano"
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
    value               = "asghf"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy, aws_autoscaling_group.autoscaling-splunk-bastion, aws_iam_role.role-splunk-hf]
}

resource "aws_launch_template" "splunk-hf" {
  provider = aws.region-master
  #name          = "splunk-hf"
  name_prefix   = "launch-template-splunk-hf"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
  key_name      = aws_key_pair.master-key.key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-hf
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = "role-splunk-hf_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-hf.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.hf
      splunkinstanceType    = var.hf
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
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("../buckets/bucket-install/install/user-data.txt")
}

