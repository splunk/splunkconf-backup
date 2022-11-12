
# ******************* CM ***********************


resource "aws_iam_role" "role-splunk-cm" {
  name                  = "role-splunk-cm-3"
  force_detach_policies = true
  description           = "iam role for splunk cm"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-cm_profile" {
  name = "role-splunk-cm_profile"
  role = aws_iam_role.role-splunk-cm.name
}

resource "aws_iam_role_policy_attachment" "cm-attach-splunk-splunkconf-backup" {
#  name       = "cm-attach-splunk-splunkconf-backup"
  role      = aws_iam_role.role-splunk-cm.name
  #roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-master
}

resource "aws_iam_role_policy_attachment" "cm-attach-splunk-route53-updatednsrecords" {
#  name       = "cm-attach-splunk-route53-updatednsrecords"
  role      = aws_iam_role.role-splunk-cm.name
  #roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-master
}

resource "aws_iam_role_policy_attachment" "cm-attach-splunk-ec2" {
#  name       = "cm-attach-splunk-ec2"
  role      = aws_iam_role.role-splunk-cm.name
  #roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-master
}

resource "aws_iam_role_policy_attachment" "cm-attach-ssm-managedinstance" {
#  name       = "cm-attach-ssm-managedinstance"
  role      = aws_iam_role.role-splunk-cm.name
  #roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  provider   = aws.region-master
}


resource "aws_security_group_rule" "cm_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "cm_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-cm.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "cm_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-cm.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "cm_from_splunkadmin-networks_webui" {
  security_group_id = aws_security_group.splunk-cm.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "cm_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-cm.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "cm_from_all_icmp" {
  security_group_id = aws_security_group.splunk-cm.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "cm_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-cm.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "cm_from_mc_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_idx_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-idx.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_sh_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_hf_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_lm_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-lm.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_ds_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_iuf_8089" {
  security_group_id        = aws_security_group.splunk-cm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-cm" {
  name                = "asg-splunk-cm"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id,local.subnet_pub_2_id,local.subnet_pub_3_id] : [local.subnet_priv_1_id,local.subnet_priv_2_id,local.subnet_priv_3_id])
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-cm.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-cm
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
    value               = var.cm
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }


  depends_on = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-cm" {
  name          = "splunk-cm"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
  key_name      = data.terraform_remote_state.ssh.outputs.ssh_key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-cm
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = "role-splunk-cm_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-cm.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.cm
      splunkinstanceType    = var.cm
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


output "cm-dns-name" {
  value = "${local.dns-prefix}${var.cm}.${var.dns-zone-name}"
  description = "cm dns name (private ip)"
}

