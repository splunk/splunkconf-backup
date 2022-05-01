

#  **************** bastion ***************

resource "aws_iam_role" "role-splunk-bastion" {
  name                  = "role-splunk-bastion"
  force_detach_policies = true
  description           = "iam role for splunk bastion"
  assume_role_policy    = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-bastion_profile" {
  name = "role-splunk-bastion_profile"
  role = aws_iam_role.role-splunk-bastion.name
}

resource "aws_iam_role_policy_attachment" "bastion-attach-splunk-ec2" {
  #name       = "bastion-attach-splunk-ec2"
  #roles      = [aws_iam_role.role-splunk-bastion.name]
  role      = aws_iam_role.role-splunk-bastion.name
  policy_arn = aws_iam_policy.pol-splunk-bastion.arn
}

resource "aws_security_group" "splunk-bastion" {
  name        = "splunk-bastion"
  description = "Security group for bastion"
  vpc_id      = aws_vpc.vpc_master.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = false
    cidr_blocks = var.splunkadmin-networks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "splunk-bastion"
  }
}

resource "aws_autoscaling_group" "autoscaling-splunk-bastion" {
  name                = "asg-splunk-bastion"
  vpc_zone_identifier = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
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
  depends_on = [null_resource.bucket_sync,aws_lambda_function.lambda_update-route53-tag,time_sleep.wait_asglambda_destroy,aws_security_group.splunk-bastion,aws_iam_role.role-splunk-bastion]
}



resource "aws_launch_template" "splunk-bastion" {
  #name          = var.bastion
  name_prefix   = "launch-template-splunk-bastion"
  image_id      = data.aws_ssm_parameter.linuxAmi.value
  key_name      = aws_key_pair.master-key.key_name
  instance_type = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 15
      volume_type = "gp3"
    }
  }
  #  ebs_optimized = true
  iam_instance_profile {
    name = "role-splunk-bastion_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.splunk-bastion.id, aws_security_group.splunk-bastion.id]
    # nat instance
    # not possible here, moved to user-data
    #source_dest_check = false
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                = var.bastion
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
  user_data = filebase64("../buckets/bucket-install/install/user-data-bastion.txt")
}

