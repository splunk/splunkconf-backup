
# ******************** HF ***********************
# A   <-> B 
# 2 instances with rsync between
# 1 instance is up
# this is the same instance in term of splunk
# this is to test and validate splunkconf-backup rsync mode, which is usually a on prem usage as in AWS you can achieve same thing with only one instance up with ASG and backups on S3



resource "tls_private_key" "splunk_ssh_key_rsync" {
  algorithm = var.ssh_algorithm
}

resource "aws_key_pair" "splunk_ssh_key_rsync" {
  #provider   = aws.region-primary
  key_name_prefix   = "splunk_ssh_key_rsync"
  public_key = tls_private_key.splunk_ssh_key_rsync.public_key_openssh
}

resource "aws_ssm_parameter" "splunk_ssh_key_rsync_priv" {
  name        = "splunk_ssh_key_rsync_priv"
  description = "priv key for splunk rsync"
  type        = "String"
  value       = tls_private_key.splunk_ssh_key_rsync.private_key_openssh
  overwrite   = true
}

resource "aws_ssm_parameter" "splunk_ssh_key_rsync_pub" {
  name        = "splunk_ssh_key_rsync_pub"
  description = "pub key for splunk rsync"
  type        = "String"
  value       = tls_private_key.splunk_ssh_key_rsync.public_key_openssh
  overwrite   = true
}


#data "template_file" "pol-splunk-ec2-rsyncssm" {
#  template = file("policy-aws/pol-splunk-ec2-rsyncssm.json.tpl")
#  vars = {
#    ssmkey1          = tls_private_key.splunk_ssh_key_rsync.private_key_openssh
#    ssmkey2          = tls_private_key.splunk_ssh_key_rsync.public_key_openssh
#    profile         = var.profile
#    splunktargetenv = var.splunktargetenv
#  }
#}

resource "aws_iam_policy" "pol-splunk-ec2-rsyncssm" {
  name_prefix = "splunkconf_ec2-rsyncssm_"
  # ... other configuration ...
  #name_prefix = local.name-prefix-pol-splunk-ec2
  description = "This policy include policy for Splunk EC2 HF  instance in rsync mode to access needed SSM in AWS SSM"
  provider    = aws.region-primary
  policy      = templatefile("policy-aws/pol-splunk-ec2-rsyncssm.json.tpl",{ssmkey1          = tls_private_key.splunk_ssh_key_rsync.private_key_openssh,
    ssmkey2          = tls_private_key.splunk_ssh_key_rsync.public_key_openssh})
}


resource "aws_iam_role_policy_attachment" "hf-attach-splunk-ec2-rsyncssm" {
  #name       = "worker-attach-splunk-ec2-rsyncssm"
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-ec2-rsyncssm.arn
}




resource "aws_iam_role" "role-splunk-hf" {
  name_prefix           = "role-splunk-hf-"
  force_detach_policies = true
  description           = "iam role for splunk hf"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-hf_profile" {
  name_prefix = "role-splunk-hf_profile"
  role        = aws_iam_role.role-splunk-hf.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-splunkconf-backup" {
  #name       = "hf-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-hf.name
  #roles      = [aws_iam_role.role-splunk-hf.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-route53-updatednsrecords" {
  #name       = "hf-attach-splunk-route53-updatednsrecords"
  #roles      = [aws_iam_role.role-splunk-hf.name]
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-ec2" {
  #name       = "hf-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-hf.name]
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "hf-attach-splunk-writesecret" {
  #name       = "hf-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-hf.name]
  role       = aws_iam_role.role-splunk-hf.name
  policy_arn = aws_iam_policy.pol-splunk-writesecret.arn
  provider   = aws.region-primary
}

#resource "aws_iam_role_policy_attachment" "hf-attach-ssm-managedinstance" {
#  #name       = "hf-attach-ssm-managedinstance"
#  #roles      = [aws_iam_role.role-splunk-hf.name]
#  role      = aws_iam_role.role-splunk-hf.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#  provider    = aws.region-primary
#}


resource "aws_security_group_rule" "hf_from_bastion_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-hf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "hf_from_worker_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-hf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-worker.id
  description              = "allow SSH connection from worker host"
}
resource "aws_security_group_rule" "hf_from_splunkadmin-networks_ssh" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

resource "aws_security_group_rule" "hf_from_splunkadmin-networks_webui" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow WebUI connection from splunk admin networks"
}

#resource "aws_security_group_rule" "hf_from_splunkadmin-networks-ipv6_ssh" { 
#  provider    = aws.region-primary
#  security_group_id = aws_security_group.splunk-hf.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

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
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_all_icmpv6" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_mc_8089" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-hf.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

# only when hf used as hec intermediate (instead of direct to idx via LB)
resource "aws_security_group_rule" "hf_from_networks_8088" {
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = setunion(var.hec-in-allowed-networks)
  description       = "allow to receive hec from authorized networks"
}

# for rsync over SSH 
resource "aws_security_group_rule" "hf_from_hf_ssh" {
  security_group_id = aws_security_group.splunk-hf.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  self              = true
  description       = "allow HF to connect to other HF via ssh port for rsync over SSH"
} 

resource "aws_autoscaling_group" "autoscaling-splunk-hfa" {
  provider = aws.region-primary
  #name                = "asg-splunk-hf"
  name_prefix         = "asg-splunk-hfa-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
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
    value               = "${var.hf}a"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  #depends_on = [null_resource.bucket_sync, aws_autoscaling_group.autoscaling-splunk-bastion, aws_iam_role.role-splunk-hf]
  depends_on = [null_resource.bucket_sync, aws_iam_role.role-splunk-hf]
}

resource "aws_autoscaling_group" "autoscaling-splunk-hfb" {
  provider = aws.region-primary
  #name                = "asg-splunk-hf"
  name_prefix         = "asg-splunk-hfb-"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
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
    value               = "${var.hf}b"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  #depends_on = [null_resource.bucket_sync, aws_autoscaling_group.autoscaling-splunk-bastion, aws_iam_role.role-splunk-hf]
  depends_on = [null_resource.bucket_sync, aws_iam_role.role-splunk-hf]
}


resource "aws_launch_template" "splunk-hf" {
  provider = aws.region-primary
  #name          = "splunk-hf"
  name_prefix   = "splunk-hf-"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
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
    name = aws_iam_instance_profile.role-splunk-hf_profile.name
    #name = "role-splunk-hf_profile"
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
      splunkacceptlicense   = var.splunkacceptlicense
      splunkpwdinit         = var.splunkpwdinit
      splunkpwdarn          = aws_secretsmanager_secret.splunk_admin.id
      splunkrsyncmode       = 1
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}



output "hf-dns-name" {
  value       = "${local.dns-prefix}${var.hf}.${var.dns-zone-name}"
  description = "hf dns name (private ip)"
}

