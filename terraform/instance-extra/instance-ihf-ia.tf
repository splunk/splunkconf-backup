# ****************** IHF with IA *******************



resource "aws_iam_role" "role-splunk-ihf" {
  name                  = "role-splunk-ihf-3"
  force_detach_policies = true
  description           = "iam role for splunk ihf"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider = aws.region-master

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ihf_profile" {
  name = "role-splunk-ihf_profile"
  role = aws_iam_role.role-splunk-ihf.name
  provider = aws.region-master
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-splunkconf-backup" {
  #name       = "ihf-attach-splunk-splunkconf-backup"
  role      = aws_iam_role.role-splunk-ihf.name
  #roles      = [aws_iam_role.role-splunk-ihf.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider = aws.region-master
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-route53-updatednsrecords" {
  #name       = "ihf-attach-splunk-route53-updatednsrecords"
  role      = aws_iam_role.role-splunk-ihf.name
  #roles      = [aws_iam_role.role-splunk-ihf.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider = aws.region-master
}

resource "aws_iam_role_policy_attachment" "ihf-attach-splunk-ec2" {
  #name       = "ihf-attach-splunk-ec2"
  role      = aws_iam_role.role-splunk-ihf.name
  #roles      = [aws_iam_role.role-splunk-ihf.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider = aws.region-master
}

resource "aws_iam_role_policy_attachment" "ihf-attach-ssm-managedinstance" {
  #name       = "iuf-attach-ssm-managedinstance"
  role      = aws_iam_role.role-splunk-ihf.name
  #roles      = [aws_iam_role.role-splunk-ihf.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  provider = aws.region-master
}

resource "aws_security_group_rule" "ihf_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-ihf.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "ihf_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "iuf_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-iuf.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ihf_from_all_icmp" {
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ihf_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-ihf.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-ihf" {
  name                = "asg-splunk-ihf"
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [aws_subnet.subnet_pub_1.id, aws_subnet.subnet_pub_2.id, aws_subnet.subnet_pub_3.id] : [aws_subnet.subnet_priv_1.id, aws_subnet.subnet_priv_2.id, aws_subnet.subnet_priv_3.id])
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
        instance_type = var.instance-type-ihf
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
    value               = "asgihf"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy]
}

resource "aws_launch_template" "splunk-ihf" {
  name          = "splunk-ihf"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
  key_name      = data.terraform_remote_state.ssh.ssh_key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.disk-size-ihf
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  #  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = "role-splunk-ihf_profile"
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
      # special UF
      splunktargetbinary  = var.splunktargetbinary
      splunktargetcm      = var.cm
      splunktargetlm      = var.lm
      splunktargetds      = var.ds
      splunkcloudmode     = var.splunkcloudmode
      splunkosupdatemode  = var.splunkosupdatemode
      splunkconnectedmode = var.splunkconnectedmode
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("../buckets/bucket-install/install/user-data.txt")
}
