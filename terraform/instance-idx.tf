
# ******************** IDX ********************

resource "aws_iam_role" "role-splunk-idx" {
  name = "role-splunk-idx-3"
  force_detach_policies = true
  description = "iam role for splunk idx"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-idx_profile" {
  name  = "role-splunk-idx_profile"
  role = aws_iam_role.role-splunk-idx.name
}

resource "aws_iam_policy_attachment" "idx-attach-splunk-splunkconf-backup" {
  name       = "idx-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "idx-attach-splunk-route53-updatednsrecords" {
  name       = "idx-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "idx-attach-splunk-ec2" {
  name       = "idx-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_iam_policy_attachment" "idx-attach-splunk-smartstore" {
  name       = "idx-attach-splunk-smartstore"
  roles      = [aws_iam_role.role-splunk-idx.name]
  policy_arn = aws_iam_policy.pol-splunk-smartstore.arn
}


resource "aws_security_group" "splunk-idx" {
  name = "splunk-idx"
  description = "Security group for Splunk Enterprise indexers"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-idx"
  }
}

# see https://discuss.hashicorp.com/t/discussion-of-aws-security-group-rules-for-absolute-management-while-avoiding-cyclical-dependencies/9647
# security group are referencing each other in a splunk deployment creating a cycling dependency (still a issue with terraform 0.13.5 at the least)
# until another solution exist (could be a future terraform version that automagically completelly this ?) , we have to use multiple levels with group rules , see link above

resource "aws_security_group_rule" "idx_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "idx_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "idx_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-idx.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "idx_from_idx_8089" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  self      = true
  description = "allow IDX to connect to other IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_cm_8089" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description = "allow CM to connect to IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to IDX on mgt port"
}

resource "aws_security_group_rule" "idx_from_sh_8089" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description = "allow SH to connect to IDX on mgt port for searches"
}

resource "aws_security_group_rule" "idx_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "idx_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "idx_from_lbhec_8088" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8088
  to_port   = 8088
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-lbhec.id
  description = "allow ELB to send HEC to IDX"
}

resource "aws_security_group_rule" "idx_from_networks_8088" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 8088
  to_port   = 8088
  protocol  = "tcp"
  cidr_blocks = var.hec-in-allowed-networks
  description = "allow IDX to receive hec from authorized networks"
}

resource "aws_security_group_rule" "idx_from_idx_9887" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9887
  to_port   = 9887
  protocol  = "tcp"
  self      = true
  description = "allow IDX to connect to other IDX for inter cluster replication"
}

resource "aws_security_group_rule" "idx_from_mc_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_sh_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_ds_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_cm_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_lm_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-lm.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_hf_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_iuf_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description = "allow to receive logs via S2S"
}

resource "aws_security_group_rule" "idx_from_networks_log" { 
  security_group_id = aws_security_group.splunk-idx.id
  type      = "ingress"
  from_port = 9997
  to_port   = 9999
  protocol  = "tcp"
  cidr_blocks = ["127.0.0.1/32"]
  description = "allow to receive logs via S2S (remote networks)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-idx" {
  name = "asg-splunk-idx"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 3
  max_size           = 3
  min_size           = 3
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-idx.id
        version = "$Latest"
      }
      override {
        instance_type     = local.instance-type-indexer
      }
    }
  }
#  provisioner "local-exec" {
#    command = "./build-idx-scripts.sh ${local.instance-type-indexer}"
#  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-idx {
  name = "splunk-idx"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp3"
    }
  }
  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size = 35
      volume_type = "gp3"
    }
  }
#  ebs_optimized = true
#  vpc_security_group_ids = [aws_security_group.splunk-idx.id]
  iam_instance_profile {
    name = "role-splunk-idx_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-idx.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "idx"
      splunkinstanceType = "idx"
      splunks3backupbucket = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket = aws_s3_bucket.s3_data.id
      splunkawsdnszone = var.dns-zone-name
      splunkorg = var.splunkorg
      splunktargetcm = var.cm
      splunktargetlm = var.lm
      splunktargetds = var.ds
    }
  }
  user_data = filebase64("../buckets/bucket-install/install/user-data.txt")
} 

# ***************** LB HEC **********************
resource "aws_security_group" "splunk-lbhec" {
  name = "splunk-lbhec"
  description = "Security group for Splunk LB for HEC to idx"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-lbhec"
  }
}

resource "aws_security_group_rule" "lbhec_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbhec_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}


resource "aws_security_group_rule" "lbhec_from_firehose_8088" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type      = "ingress"
  from_port = 8088
  to_port   = 8088
  protocol  = "tcp"
  cidr_blocks = var.hec-in-allowed-firehose-networks
  description = "allow hec from firehose networks"
}

resource "aws_security_group_rule" "lbhec_from_networks_8088" {
  security_group_id = aws_security_group.splunk-lbhec.id
  type      = "ingress"
  from_port = 8088
  to_port   = 8088
  protocol  = "tcp"
  cidr_blocks = var.hec-in-allowed-networks
  description = "allow hec from authorized networks"
}

