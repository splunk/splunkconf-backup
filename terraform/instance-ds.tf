# ********************* DS *******************
resource "aws_iam_role" "role-splunk-ds" {
  name                  = "role-splunk-ds-3"
  force_detach_policies = true
  description           = "iam role for splunk ds"
  assume_role_policy    = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ds_profile" {
  name = "role-splunk-ds_profile"
  role = aws_iam_role.role-splunk-ds.name
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-splunkconf-backup" {
  name       = "ds-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-route53-updatednsrecords" {
  name       = "ds-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-ec2" {
  name       = "ds-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_iam_policy_attachment" "ds-attach-ssm-managedinstance" {
  name       = "ds-attach-ssm-managedinstance"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
  name                = "asg-splunk-ds"
  vpc_zone_identifier = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-ds.id
        version            = "$Latest"
      }
      override {
        instance_type = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-ds" {
  name          = "splunk-ds"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
  key_name      = aws_key_pair.master-key.key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
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
    associate_public_ip_address = true
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



