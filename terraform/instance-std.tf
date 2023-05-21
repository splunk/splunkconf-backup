
# ******************** Standalone with S2 ***********************

resource "aws_iam_role" "role-splunk-std" {
  name_prefix           = "role-splunk-std"
  force_detach_policies = true
  description           = "iam role for splunk standalone with S2"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-std_profile" {
  name_prefix = "role-splunk-std_profile"
  role        = aws_iam_role.role-splunk-std.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "std-attach-splunk-splunkconf-backup" {
  #name       = "std-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-std.name
  #roles      = [aws_iam_role.role-splunk-std.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "std-attach-splunk-route53-updatednsrecords" {
  #name       = "std-attach-splunk-route53-updatednsrecords"
  #roles      = [aws_iam_role.role-splunk-std.name]
  role       = aws_iam_role.role-splunk-std.name
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "std-attach-splunk-ec2" {
  #name       = "std-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-std.name]
  role       = aws_iam_role.role-splunk-std.name
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "std-attach-splunk-smartstore" {
  #name       = "std-attach-splunk-smartstore"
  role = aws_iam_role.role-splunk-std.name
  #roles      = [aws_iam_role.role-splunk-std.name]
  policy_arn = aws_iam_policy.pol-splunk-smartstore.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "std-attach-splunk-writesecret" {
  #name       = "std-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-std.name]
  role       = aws_iam_role.role-splunk-std.name
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

#resource "aws_iam_role_policy_attachment" "std-attach-ssm-managedinstance" {
#  #name       = "std-attach-ssm-managedinstance"
#  #roles      = [aws_iam_role.role-splunk-std.name]
#  role      = aws_iam_role.role-splunk-std.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#  provider    = aws.region-primary
#}


resource "aws_security_group_rule" "std_from_bastion_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-std.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "std_from_splunkadmin-networks_ssh" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-std.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

resource "aws_security_group_rule" "std_from_networks_webui" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-std.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks, var.users-networks)
  description       = "allow WebUI connection from authorixed networks"
}

#resource "aws_security_group_rule" "std_from_splunkadmin-networks-ipv6_ssh" { 
#  provider    = aws.region-primary
#  security_group_id = aws_security_group.splunk-dtd.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

#resource "aws_security_group_rule" "std_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-std.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "std_from_all_icmp" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-std.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

#resource "aws_security_group_rule" "std_from_all_icmpv6" {
#  provider          = aws.region-primary
#  security_group_id = aws_security_group.splunk-std.id
#  type              = "ingress"
#  from_port         = -1
#  to_port           = -1
#  protocol          = "icmpv6"
#  ipv6_cidr_blocks  = ["::/0"]
#  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
#}

resource "aws_security_group_rule" "std_from_mc_8089" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-std.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "std_from_networks_8088" {
  security_group_id = aws_security_group.splunk-std.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks)
  description       = "allow Standalone to receive hec from authorized networks"
}

resource "aws_security_group_rule" "std_from_networks_log" {
  security_group_id = aws_security_group.splunk-std.id
  type              = "ingress"
  from_port         = 9997
  to_port           = 9999
  protocol          = "tcp"
  cidr_blocks       = setunion(var.s2s-in-allowed-networks)
  description       = "allow to receive logs via S2S (remote networks)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-std" {
  provider            = aws.region-primary
  name_prefix         = "asg-splunk-std-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-std.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-std
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
    value               = var.std
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  #depends_on = [null_resource.bucket_sync, aws_autoscaling_group.autoscaling-splunk-bastion, aws_iam_role.role-splunk-std]
  depends_on = [null_resource.bucket_sync, aws_iam_role.role-splunk-std]
}

resource "aws_launch_template" "splunk-std" {
  provider = aws.region-primary
  #name          = "splunk-std"
  name_prefix   = "splunk-std-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-std
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = aws_iam_instance_profile.role-splunk-std_profile.name
    #name = "role-splunk-std_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-std.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.std
      splunkinstanceType    = var.std
      splunks3backupbucket  = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket    = aws_s3_bucket.s3_data.id
      splunkdnszone         = var.dns-zone-name
      splunkdnsmode         = "lambda"
      splunkorg             = var.splunkorg
      splunktargetenv       = var.splunktargetenv
      splunktargetbinary    = var.splunktargetbinary
      # should be not needed for std but if configured at app level only , it will be used either it should do nothing 
      splunktargetcm      = var.cm
      splunktargetlm      = var.lm
      splunktargetds      = var.ds
      splunkcloudmode     = var.splunkcloudmode
      splunkosupdatemode  = var.splunkosupdatemode
      splunkconnectedmode = var.splunkconnectedmode
      splunkacceptlicense = var.splunkacceptlicense
      splunkpwdinit       = var.splunkpwdinit
      splunkpwdarn        = aws_secretsmanager_secret.splunk_admin.id
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}

output "std-dns-name" {
  value       = "${local.dns-prefix}${var.std}.${var.dns-zone-name}"
  description = "Standalone with S2 (std) dns name (private ip)"
}

output "std-dns-name-ext" {
  value       = var.associate_public_ip ? "${local.dns-prefix}${var.std}-ext.${var.dns-zone-name}" : "disabled"
  description = "Standalone with S2 (std) ext dns name (pub ip)"
}

output "std-url" {
  value       = var.associate_public_ip ? "https://${local.dns-prefix}${var.std}-ext.${var.dns-zone-name}:8000" : "https://${local.dns-prefix}${var.std}.${var.dns-zone-name}:8000"
  description = "std url"
}

output "std-sshconnection" {
  value       = var.associate_public_ip ? "ssh -i mykey-${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.std}-ext.${var.dns-zone-name}" : "ssh -i mykey-${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.std}.${var.dns-zone-name}"
  description = "std ssh connection"
}

