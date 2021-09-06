

#  **************** bastion ***************

resource "aws_security_group" "splunk-bastion" {
  name = "splunk-bastion"
  description = "Security group for bastion"
  vpc_id = aws_vpc.vpc_master.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    self = false
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
  name = "asg-splunk-bastion"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_2.id,aws_subnet.subnet_3.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-bastion.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}



resource aws_launch_template splunk-bastion {
  name = var.bastion
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
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
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-bastion.id,aws_security_group.splunk-bastion.id]
    # nat instance
    source_dest_check = false
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.bastion
      splunkinstanceType = var.bastion
      splunkosupdatemode = var.splunkosupdatemode
      splunkconnectedmode = var.splunkconnectedmode
    }
  }
  user_data = filebase64("../buckets/bucket-install/install/user-data-bastion.txt")
}


