# ******************* SH ****************

resource "aws_iam_role" "role-splunk-sh" {
  name_prefix           = "role-splunk-sh-"
  force_detach_policies = true
  description           = "iam role for splunk sh"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-sh_profile" {
  name_prefix = "role-splunk-sh_profile"
  role        = aws_iam_role.role-splunk-sh.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "sh-attach-splunk-splunkconf-backup" {
  #name       = "sh-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-sh.name
  #roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "sh-attach-splunk-route53-updatednsrecords" {
  #name       = "sh-attach-splunk-route53-updatednsrecords"
  role = aws_iam_role.role-splunk-sh.name
  #roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "sh-attach-splunk-ec2" {
  #name       = "sh-attach-splunk-ec2"
  role = aws_iam_role.role-splunk-sh.name
  #roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "sh-attach-splunk-writesecret" {
  role = aws_iam_role.role-splunk-sh.name
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "sh-attach-ssm-managedinstance" {
  #name       = "sh-attach-ssm-managedinstance"
  role = aws_iam_role.role-splunk-sh.name
  #roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  provider   = aws.region-primary
}


resource "aws_security_group_rule" "sh_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-sh.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "sh_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "sh_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-sh.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

#resource "aws_security_group_rule" "sh_from_splunkadmin-networks_webui" {
#  security_group_id = aws_security_group.splunk-sh.id
#  type              = "ingress"
#  from_port         = 8000
#  to_port           = 8000
#  protocol          = "tcp"
#  cidr_blocks       = var.splunkadmin-networks
#  description       = "allow Webui connection from splunk admin networks"
#}

#resource "aws_security_group_rule" "sh_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-sh.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "sh_from_all_icmp" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "sh_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "sh_from_mc_8089" {
  security_group_id        = aws_security_group.splunk-sh.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "sh_from_cm_8089" {
  security_group_id        = aws_security_group.splunk-sh.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "sh_from_trustedrestapi_8089" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = var.trustedrestapi_to_sh
  description       = "allow connect to sh on mgt port (rest api) from extra trusted ip(s)"
}

resource "aws_security_group_rule" "sh_from_lbsh_8000" {
  security_group_id        = aws_security_group.splunk-sh.id
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-lbsh.id
  description              = "allow connect to instance on web ui"
}

resource "aws_security_group_rule" "sh_from_usersnetworks_8000" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = setunion( var.users-networks, var.splunkadmin-networks)
  description       = "allow connect to instance on web ui"
}

resource "aws_security_group_rule" "sh_from_usersnetworks-ipv6_8000" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  ipv6_cidr_blocks  = var.users-networks-ipv6
  description       = "allow connect to instance on web ui"
}

resource "aws_security_group_rule" "sh_from_sh_8080" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  self              = true
  description       = "allow SH to connect to other SH for inter cluster replication"
}

resource "aws_security_group_rule" "sh_from_sh_8191" {
  security_group_id = aws_security_group.splunk-sh.id
  type              = "ingress"
  from_port         = 8191
  to_port           = 8191
  protocol          = "tcp"
  self              = true
  description       = "allow SH to connect to other SH for inter cluster replication (kvstore)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-sh" {
  #name                = "asg-splunk-sh"
  name_prefix          = "asg-splunk-sh-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-sh.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-sh
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
    value               = var.sh
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }


  depends_on = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-sh" {
  #name          = "splunk-sh"
  name_prefix    = "splunk-sh-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = local.instance-type-sh
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-sh
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  #  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    #name = "role-splunk-sh_profile"
    name = aws_iam_instance_profile.role-splunk-sh_profile.name
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-sh.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = var.sh
      splunkinstanceType    = var.sh
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
      splunkcloudmode       = var.splunkcloudmode
      splunkosupdatemode    = var.splunkosupdatemode
      splunkconnectedmode   = var.splunkconnectedmode
      splunkacceptlicense   = var.splunkacceptlicense
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}

# ***************** LB SH  **********************
resource "aws_security_group" "splunk-lbsh" {
  name        = "splunk-lbsh"
  description = "Security group for Splunk LB in front of sh(s)"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-lbsh"
  }
}

resource "aws_security_group_rule" "lbsh_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbsh_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbsh_from_bastion_https" {
  security_group_id        = aws_security_group.splunk-lbsh.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow connection to lb sh from bastion"
}

resource "aws_security_group_rule" "lbsh_from_networks_https" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["127.0.0.10/32"]
  description       = "allow https connection to lb sh from authorized networks"
}


output "sh-dns-name" {
  value       = "${local.dns-prefix}${var.sh}.${var.dns-zone-name}"
  description = "sh dns name (private ip)"
}

output "sh-dns-name-ext" {
  value       = var.associate_public_ip ? "${local.dns-prefix}${var.sh}-ext.${var.dns-zone-name}" : "disabled"
  description = "sh ext dns name (pub ip)"
}

output "sh-url" {
  value       = var.associate_public_ip ? "https://${local.dns-prefix}${var.sh}-ext.${var.dns-zone-name}:8000" : "https://${local.dns-prefix}${var.sh}.${var.dns-zone-name}:8000"
  description = "sh url"
}

output "sh-sshconnection" {
  value       = var.associate_public_ip ? "ssh -i mykey${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.sh}-ext.${var.dns-zone-name}" : "ssh -i mykey${var.region-primary}.priv ec2-user@${local.dns-prefix}${var.sh}.${var.dns-zone-name}"
  description = "sh ssh connection "
}
