

#  **************** github worker running inside AWS  ***************


resource "aws_iam_instance_profile" "role-splunk-worker_profile" {
  name_prefix = "role-splunk-worker_profile"
  role        = aws_iam_role.role-splunk-worker.name
  provider    = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "worker-attach-splunk-ec2worker" {
  #name       = "worker-attach-splunk-ec2worker"
  role       = aws_iam_role.role-splunk-worker.name
  policy_arn = aws_iam_policy.pol-splunk-ec2worker.arn
}

resource "aws_security_group_rule" "worker_from_bastion_ssh" {
  provider                 = aws.region-primary
  security_group_id        = aws_security_group.splunk-worker.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_autoscaling_group" "autoscaling-splunk-worker" {
  name                = "asg-splunk-worker"
  vpc_zone_identifier = [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-worker.id
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
    value               = var.worker
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }
  depends_on = [null_resource.bucket_sync, aws_security_group.splunk-worker, aws_iam_role.role-splunk-worker]
  #depends_on = [null_resource.bucket_sync, aws_lambda_function.lambda_update-route53-tag, time_sleep.wait_asglambda_destroy, aws_security_group.splunk-bastion, aws_iam_role.role-splunk-bastion]
}



resource "aws_launch_template" "splunk-worker" {
  provider      = aws.region-primary
  name_prefix   = "splunk-worker-"
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
    name = aws_iam_instance_profile.role-splunk-worker_profile.name
    #name = "role-splunk-worker_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = false
    security_groups             = [aws_security_group.splunk-worker.id, aws_security_group.splunk-outbound.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                = var.worker
      splunkinstanceType  = var.worker
      splunkosupdatemode  = var.splunkosupdatemode
      splunkconnectedmode = var.splunkconnectedmode
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data-worker.txt")
}


output "worker-dns-name" {
  value       = local.worker-dns-name
  description = "worker dns name (private ip)"
}

