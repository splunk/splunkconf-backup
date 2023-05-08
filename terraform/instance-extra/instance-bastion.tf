
#  **************** bastion ***************

resource "aws_iam_role" "role-splunk-bastion" {
  name_prefix           = "role-splunk-bastion"
  force_detach_policies = true
  description           = "iam role for splunk bastion"
  assume_role_policy    = file("./policy-aws/assumerolepolicy.json")
  #assume_role_policy    = file("../../policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-bastion_profile" {
  name_prefix = "role-splunk-bastion_profile"
  role = aws_iam_role.role-splunk-bastion.name
}

resource "aws_iam_role_policy_attachment" "bastion-attach-splunk-ec2" {
  #name       = "bastion-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-bastion.name]
  role       = aws_iam_role.role-splunk-bastion.name
  policy_arn = aws_iam_policy.pol-splunk-bastion.arn
}


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

resource "aws_security_group_rule" "bastion_from_splunkadmin-networks_ssh" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-bastion.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = setunion(var.splunkadmin-networks)
  description       = "allow SSH connection from splunk admin networks"
}

# this is only used when not using a nat gateway (lab)
# no harm if present otherwise
# 
resource "aws_security_group_rule" "bastion_natinstance" {
  provider          = aws.region-primary
  security_group_id = aws_security_group.splunk-bastion.id
  type              = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = -1
  security_groups = [aws_security_group.splunk-hf.id, aws_security_group.splunk-cm.id, aws_security_group.splunk-ds.id, aws_security_group.splunk-idx.id, aws_security_group.splunk-sh.id, aws_security_group.splunk-iuf.id, aws_security_group.splunk-mc.id,aws_security_group.splunk-worker.id]
  self            = true
  description       = "allow instance to be used as instance gateway from internal hosts only"
}

resource "aws_security_group" "splunk-bastion" {
  name        = "splunk-bastion"
  description = "Security group for bastion"
  vpc_id      = local.master_vpc_id
}

resource "aws_autoscaling_group" "autoscaling-splunk-bastion" {
  name = "asg-splunk-bastion"
  # note : this has to be on pub network for the bastion to be reachable from outside
  vpc_zone_identifier = [local.subnet_pub_1_id, local.subnet_pub_2_id, local.subnet_pub_3_id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-bastion.id
        version            = "$Latest"
      }
      override {
        instance_type = "t3a.nano"
      }
    }
  }

  tag {
    key                 = "splunkdnszone"
    value               = var.dns-zone-name
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsnames"
    value               = var.bastion
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }
  depends_on = [null_resource.bucket_sync, aws_security_group.splunk-bastion, aws_iam_role.role-splunk-bastion]
  #depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy, aws_security_group.splunk-bastion, aws_iam_role.role-splunk-bastion]
}



resource "aws_launch_template" "splunk-bastion" {
  #name          = var.bastion
  name_prefix = "launch-template-splunk-bastion"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
  instance_type = "t3a.nano"
  # just recreate one if needed
  instance_initiated_shutdown_behavior = "terminate"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 15
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = aws_iam_instance_profile.role-splunk-bastion_profile.name
    #name = "role-splunk-bastion_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-bastion.id]
    # nat instance
    # not possible here, moved to user-data
    #source_dest_check = false
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.bastion
      # not used for bastion 
      #      splunkinstanceType  = var.bastion
      #      splunkosupdatemode  = var.splunkosupdatemode
      #      splunkconnectedmode = var.splunkconnectedmode
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data-bastion.txt")
}

#resource "aws_network_interface" "bastion_1" {
#  subnet_id       = aws_subnet.subnet_pub_1.id
#  private_ips     = ["10.0.1.50"]
#  security_groups = [aws_security_group.splunk-bastion.id]
#
#}

#resource "aws_network_interface" "bastion_2" {
#  subnet_id       = aws_subnet.subnet_pub_2.id
#  private_ips     = ["10.0.2.50"]
#  security_groups = [aws_security_group.splunk-bastion.id]
#
#}

#resource "aws_network_interface" "bastion_3" {
#  subnet_id       = aws_subnet.subnet_pub_3.id
#  private_ips     = ["10.0.3.50"]
#  security_groups = [aws_security_group.splunk-bastion.id]
#}


output "bastion-dns-name-ext" {
  value       = "${local.dns-prefix}${var.bastion}-ext.${var.dns-zone-name}"
  description = "Bastion dns name (public ip)"
}

output "bastion-dns-name" {
  value       = "${local.dns-prefix}${var.bastion}.${var.dns-zone-name}"
  description = "Bastion dns name (private ip)"
}

