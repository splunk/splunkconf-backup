
resource "aws_autoscaling_group" "autoscaling-splunk-ihf3" {
  name = "asg-splunk-ihf3"
  #  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id,local.subnet_pub_2_id,local.subnet_pub_3_id] : [local.subnet_priv_1_id,local.subnet_priv_2_id,local.subnet_priv_3_id])
  vpc_zone_identifier = (var.associate_public_ip == "true" ? [local.subnet_pub_1_id] : [local.subnet_priv_1_id, local.subnet_priv_2_id, local.subnet_priv_3_id])
  desired_capacity    = var.ihf3-nb
  max_size            = var.ihf3-nb
  min_size            = var.ihf3-nb
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.splunk-ihf3.id
        version            = "$Latest"
      }
      override {
        instance_type = local.instance-type-ihf
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
    value               = "ihf3"
    propagate_at_launch = false
  }
  tag {
    key                 = "splunkdnsprefix"
    value               = local.dns-prefix
    propagate_at_launch = false
  }

  depends_on = [null_resource.bucket_sync]
}

resource "aws_launch_template" "splunk-ihf3" {
  name          = "splunk-ihf3"
  image_id      = local.image_id
  key_name      = local.ssh_key_name
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
    name = aws_iam_instance_profile.role-splunk-ihf_profile.name
    #name = "role-splunk-ihf_profile"
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.splunk-outbound.id, aws_security_group.splunk-ihf.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = "${var.ihf}3"
      splunkinstanceType    = "${var.ihf}3"
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
      splunkacceptlicense = var.splunkacceptlicense
      splunkpwdinit         = var.splunkpwdinit
      splunkpwdarn          = aws_secretsmanager_secret.splunk_admin.id
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = (var.imdsv2 == "required" ? "required" : "optional")
    http_put_response_hop_limit = 1
  }
  user_data = filebase64("./user-data/user-data.txt")
}

output "ihf-dns-name3" {
  value       = "${local.dns-prefix}${var.ihf}3.${var.dns-zone-name}"
  description = "ihf3 dns name (private ip)"
}

output "ihf-dns-name-ext3" {
  value       = "${local.dns-prefix}${var.ihf}3-ext.${var.dns-zone-name}"
  description = "ihf3 dns name (pub ip) (if exist)"
}




