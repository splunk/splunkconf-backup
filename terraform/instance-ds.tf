# ********************* DS *******************
resource "aws_iam_role" "role-splunk-ds" {
  name                  = "role-splunk-ds-3"
  force_detach_policies = true
  description           = "iam role for splunk ds"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ds_profile" {
  name     = "role-splunk-ds_profile"
  role     = aws_iam_role.role-splunk-ds.name
  provider = aws.region-primary
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




resource "aws_security_group_rule" "ds_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-ds.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "ds_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
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
  cidr_blocks       = var.splunkadmin-networks
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
  cidr_blocks       = ["127.0.0.19/32"]
  description       = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_networks_ipv6_8089" {
  security_group_id = aws_security_group.splunk-ds.id
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  ipv6_cidr_blocks  = ["::1/128"]
  description       = "allow connect to instance on mgt port (rest api)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-ds" {
  provider            = aws.region-primary
  name                = "asg-splunk-ds"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
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


  #depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy]
  depends_on = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-ds" {
  #name          = "splunk-ds"
  name_prefix   = "splunk-ds-"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
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
    name = "role-splunk-ds_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-ds.id]
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
      splunktargetbinary    = var.splunktargetbinary
      splunktargetcm        = var.cm
      splunktargetlm        = var.lm
      splunktargetds        = var.ds
      splunkcloudmode       = var.splunkcloudmode
      splunkosupdatemode    = var.splunkosupdatemode
      splunkconnectedmode   = var.splunkconnectedmode
      splunkacceptlicense   = var.splunkacceptlicense
      splunkpwdinit         = var.splunkpwdinit
      splunkpwdarn	    = aws_secretsmanager_secret.splunk_admin.id
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}



output "ds-dns-name" {
  value       = "${local.dns-prefix}${var.ds}.${var.dns-zone-name}"
  description = "ds dns name (private ip)"
}

