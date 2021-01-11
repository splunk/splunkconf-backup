data "template_file" "pol-splunk-ec2" {
  template = file("policy-aws/pol-splunk-ec2.json.tpl")

  vars = {
    s3_install      = aws_s3_bucket.s3_install.arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

locals {
  name-prefix-pol-splunk-ec2 = "pol-splunk-ec2-${var.profile}-$(var.region-master}-${var.splunktargetenv}"
}

resource "aws_iam_policy" "pol-splunk-ec2" {
  # ... other configuration ...
  #name_prefix = local.name-prefix-pol-splunk-ec2
  description = "This policy include shared policy for Splunk EC2 instances"
  provider    = aws.region-master
  policy      = data.template_file.pol-splunk-ec2.rendered
}

data "template_file" "pol-splunk-splunkconf-backup" {
  template = file("policy-aws/pol-splunk-splunkconf-backup.json.tpl")

  vars = {
    s3_backup       = aws_s3_bucket.s3_backup.arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-splunkconf-backup" {
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-splunkconf-backup-${var.profile}-$(var.region-master}-${var.splunktargetenv}"
  #}
  description = "This policy allow instance to upload backup and fetch files for restauration in the bucket used for backups. Note that instances cant delete backups as this is completely managed by a lifecycle policy by design"
  provider    = aws.region-master
  policy      = data.template_file.pol-splunk-splunkconf-backup.rendered
}

data "template_file" "pol-splunk-route53-updatednsrecords" {
  template = file("policy-aws/pol-splunk-route53-updatednsrecords.json.tpl")

  vars = {
    zone-id         = aws_route53_zone.dnszone.id
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-route53-updatednsrecords" {
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-splunkconf-backup-${var.profile}-$(var.region-master}-${var.splunktargetenv}"
  #}
  description = "Allow to update dns records from ec2 instance at instance creation"
  provider    = aws.region-master
  policy      = data.template_file.pol-splunk-route53-updatednsrecords.rendered
}

data "template_file" "pol-splunk-smartstore" {
  template = file("policy-aws/pol-splunk-smartstore.json.tpl")

  vars = {
    s3_data         = aws_s3_bucket.s3_data.arn
    profile         = var.profile
    splunktargetenv = var.splunktargetenv
  }
}

resource "aws_iam_policy" "pol-splunk-smartstore" {
  # ... other configuration ...
  #statement {
  #  sid = "pol-splunk-smartstore-${var.profile}-$(var.region-master}-${var.splunktargetenv}"
  #}
  description = "Permissions needed for SmartStore"
  provider    = aws.region-master
  policy      = data.template_file.pol-splunk-smartstore.rendered
}



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

# ******************** OUTBOUND  ********************
resource "aws_security_group" "splunk-outbound" {
  name = "splunk-outbound"
  description = "Outbound Security group"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk"
  }
}

resource "aws_security_group_rule" "idx_outbound_all" { 
  security_group_id = aws_security_group.splunk-outbound.id
  type = "egress" 
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow all outbound traffic"
}

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
      volume_type = "gp2"
    }
  }
  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size = 35
      volume_type = "gp2"
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
  user_data = filebase64("install/user-data.txt")
} 


# ******************* CM ***********************


resource "aws_iam_role" "role-splunk-cm" {
  name = "role-splunk-cm-3"
  force_detach_policies = true
  description = "iam role for splunk cm"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-cm_profile" {
  name  = "role-splunk-cm_profile"
  role = aws_iam_role.role-splunk-cm.name
}

resource "aws_iam_policy_attachment" "cm-attach-splunk-splunkconf-backup" {
  name       = "cm-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "cm-attach-splunk-route53-updatednsrecords" {
  name       = "cm-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "cm-attach-splunk-ec2" {
  name       = "cm-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-cm.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}


resource "aws_security_group" "splunk-cm" {
  name = "splunk-cm"
  description = "Security group for Splunk CM(MN)"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-cm"
  }
}

resource "aws_security_group_rule" "cm_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "cm_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "cm_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-cm.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "cm_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "cm_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-cm.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "cm_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "cm_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "cm_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_idx_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-idx.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_sh_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_hf_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_lm_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-lm.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_ds_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "cm_from_iuf_8089" { 
  security_group_id = aws_security_group.splunk-cm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-cm" {
  name = "asg-splunk-cm"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-cm.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-cm {
  name = "splunk-cm"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
  iam_instance_profile {
    name = "role-splunk-cm_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-cm.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.cm
      splunkinstanceType = var.cm
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
  user_data = filebase64("install/user-data.txt")
} 

# ********************* DS *******************
resource "aws_iam_role" "role-splunk-ds" {
  name = "role-splunk-ds-3"
  force_detach_policies = true
  description = "iam role for splunk ds"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-ds_profile" {
  name  = "role-splunk-ds_profile"
  role = aws_iam_role.role-splunk-ds.name
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-splunkconf-backup" {
  name       = "ds-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-route53-updatednsrecords" {
  name       = "ds-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "ds-attach-splunk-ec2" {
  name       = "ds-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-ds.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}


resource "aws_security_group" "splunk-ds" {
  name = "splunk-ds"
  description = "Security group for Splunk DS"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-ds"
  }
}

resource "aws_security_group_rule" "ds_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "ds_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "ds_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-ds.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ds_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "ds_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-ds.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "ds_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ds_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "ds_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_sh_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_cm_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_hf_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_iuf_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-iuf.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_networks_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  cidr_blocks = ["127.0.0.19/32"]
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "ds_from_networks_ipv6_8089" { 
  security_group_id = aws_security_group.splunk-ds.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  ipv6_cidr_blocks = ["::1/128"]
  description = "allow connect to instance on mgt port (rest api)"
}
 
resource "aws_autoscaling_group" "autoscaling-splunk-ds" {
  name = "asg-splunk-ds"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-ds.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-ds {
  name = "splunk-ds"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
#  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = "role-splunk-ds_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-ds.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.ds
      splunkinstanceType = var.ds
      splunks3backupbucket = aws_s3_bucket.s3_backup.id
      splunks3installbucket = aws_s3_bucket.s3_install.id
      splunks3databucket = aws_s3_bucket.s3_data.id
      splunkawsdnszone = var.dns-zone-name
      splunkorg = var.splunkorg
      splunktargetcm = var.cm
      splunktargetlm = var.lm
      splunktargetds = var.ds
      splunkdsnb = var.dsnb
    }
  }
  user_data = filebase64("install/user-data.txt")
}



# *********************** MC ********************

resource "aws_iam_role" "role-splunk-mc" {
  name = "role-splunk-mc-3"
  force_detach_policies = true
  description = "iam role for splunk mc"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-mc_profile" {
  name  = "role-splunk-mc_profile"
  role = aws_iam_role.role-splunk-mc.name
}

resource "aws_iam_policy_attachment" "mc-attach-splunk-splunkconf-backup" {
  name       = "mc-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-mc.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "mc-attach-splunk-route53-updatednsrecords" {
  name       = "mc-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-mc.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "mc-attach-splunk-ec2" {
  name       = "mc-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-mc.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_security_group" "splunk-mc" {
  name = "splunk-mc"
  description = "Security group for Splunk Monitoring Console MC"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-mc"
  }
}

resource "aws_security_group_rule" "mc_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-mc.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "mc_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-mc.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "mc_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-mc.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "mc_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-mc.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "mc_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-mc.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "mc_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-mc.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "mc_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-mc.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-mc" {
  name = "asg-splunk-mc"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-mc.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-mc {
  name = "splunk-mc"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
#  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = "role-splunk-mc_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-mc.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.mc
      splunkinstanceType = var.mc
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
  user_data = filebase64("install/user-data.txt")
}


# ******************* SH ****************

resource "aws_iam_role" "role-splunk-sh" {
  name = "role-splunk-sh-3"
  force_detach_policies = true
  description = "iam role for splunk sh"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-sh_profile" {
  name  = "role-splunk-sh_profile"
  role = aws_iam_role.role-splunk-sh.name
}

resource "aws_iam_policy_attachment" "sh-attach-splunk-splunkconf-backup" {
  name       = "sh-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "sh-attach-splunk-route53-updatednsrecords" {
  name       = "sh-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "sh-attach-splunk-ec2" {
  name       = "sh-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-sh.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_security_group" "splunk-sh" {
  name = "splunk-sh"
  description = "Security group for Splunk SH"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-sh"
  }
}

resource "aws_security_group_rule" "sh_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "sh_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
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

resource "aws_security_group_rule" "sh_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

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
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "sh_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "sh_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "sh_from_cm_8089" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "sh_from_lbsh_8000" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-lbsh.id
  description = "allow connect to instance on web ui"
}

resource "aws_security_group_rule" "sh_from_usersnetworks_8000" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.users-networks
  description = "allow connect to instance on web ui"
}

resource "aws_security_group_rule" "sh_from_usersnetworks-ipv6_8000" { 
  security_group_id = aws_security_group.splunk-sh.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  ipv6_cidr_blocks = var.users-networks-ipv6
  description = "allow connect to instance on web ui"
}

resource "aws_autoscaling_group" "autoscaling-splunk-sh" {
  name = "asg-splunk-sh"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-sh.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-sh {
  name = "splunk-sh"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
#  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = "role-splunk-sh_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-sh.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.sh
      splunkinstanceType = var.sh
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
  user_data = filebase64("install/user-data.txt")
}


# ******************* LM *************************

resource "aws_iam_role" "role-splunk-lm" {
  name = "role-splunk-lm-3"
  force_detach_policies = true
  description = "iam role for splunk lm"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-lm_profile" {
  name  = "role-splunk-lm_profile"
  role = aws_iam_role.role-splunk-lm.name
}

resource "aws_iam_policy_attachment" "lm-attach-splunk-splunkconf-backup" {
  name       = "lm-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "lm-attach-splunk-route53-updatednsrecords" {
  name       = "lm-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "lm-attach-splunk-ec2" {
  name       = "lm-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_security_group" "splunk-lm" {
  name = "splunk-lm"
  description = "Security group for Splunk License Master LM"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-lm"
  }
}

resource "aws_security_group_rule" "lm_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "lm_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "lm_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-lm.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "lm_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

#resource "aws_security_group_rule" "lm_from_splunkadmin-networks-ipv6_webui" { 
#  security_group_id = aws_security_group.splunk-lm.id
#  type      = "ingress"
#  from_port = 8000
#  to_port   = 8000
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow Webui connection from splunk admin networks"
#}

resource "aws_security_group_rule" "lm_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lm_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lm_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_cm_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_idx_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-idx.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_sh_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_ds_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_hf_8089" { 
  security_group_id = aws_security_group.splunk-lm.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description = "allow connect to instance on mgt port (rest api)"
}



# ******************** HF ***********************

resource "aws_iam_role" "role-splunk-hf" {
  name = "role-splunk-hf-3"
  force_detach_policies = true
  description = "iam role for splunk hf"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-hf_profile" {
  name  = "role-splunk-hf_profile"
  role = aws_iam_role.role-splunk-hf.name
}

resource "aws_iam_policy_attachment" "hf-attach-splunk-splunkconf-backup" {
  name       = "hf-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-hf.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "hf-attach-splunk-route53-updatednsrecords" {
  name       = "hf-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-hf.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "hf-attach-splunk-ec2" {
  name       = "hf-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-hf.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_security_group" "splunk-hf" {
  name = "splunk-hf"
  description = "Security group for Splunk HF"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-hf"
  }
}

resource "aws_security_group_rule" "hf_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "hf_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
}

#resource "aws_security_group_rule" "hf_from_splunkadmin-networks-ipv6_ssh" { 
#  security_group_id = aws_security_group.splunk-hf.id
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#  protocol  = "tcp"
#  ipv6_cidr_blocks = var.splunkadmin-networks-ipv6
#  description = "allow SSH connection from splunk admin networks"
#}

resource "aws_security_group_rule" "hf_from_splunkadmin-networks_webui" { 
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = 8000
  to_port   = 8000
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow Webui connection from splunk admin networks"
}

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
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "hf_from_mc_8089" { 
  security_group_id = aws_security_group.splunk-hf.id
  type      = "ingress"
  from_port = 8089
  to_port   = 8089
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-hf" {
  name = "asg-splunk-hf"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 0
  max_size           = 0
  min_size           = 0
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-hf.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-hf {
  name = "splunk-hf"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
  iam_instance_profile {
    name = "role-splunk-hf_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-hf.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.hf
      splunkinstanceType = var.hf
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
  user_data = filebase64("install/user-data.txt")
}

# ****************** IUF *******************

resource "aws_iam_role" "role-splunk-iuf" {
  name = "role-splunk-iuf-3"
  force_detach_policies = true
  description = "iam role for splunk iuf"
  assume_role_policy = file("policy-aws/assumerolepolicy.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-iuf_profile" {
  name  = "role-splunk-iuf_profile"
  role = aws_iam_role.role-splunk-iuf.name
}

resource "aws_iam_policy_attachment" "iuf-attach-splunk-splunkconf-backup" {
  name       = "iuf-attach-splunk-splunkconf-backup"
  roles      = [aws_iam_role.role-splunk-iuf.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
}

resource "aws_iam_policy_attachment" "iuf-attach-splunk-route53-updatednsrecords" {
  name       = "iuf-attach-splunk-route53-updatednsrecords"
  roles      = [aws_iam_role.role-splunk-iuf.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
}

resource "aws_iam_policy_attachment" "iuf-attach-splunk-ec2" {
  name       = "iuf-attach-splunk-ec2"
  roles      = [aws_iam_role.role-splunk-iuf.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
}

resource "aws_security_group" "splunk-iuf" {
  name = "splunk-iuf"
  description = "Security group for Splunk IUF"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-iuf"
  }
}

resource "aws_security_group_rule" "iuf_from_bastion_ssh" { 
  security_group_id = aws_security_group.splunk-iuf.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "iuf_from_splunkadmin-networks_ssh" { 
  security_group_id = aws_security_group.splunk-iuf.id
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = var.splunkadmin-networks
  description = "allow SSH connection from splunk admin networks"
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

resource "aws_security_group_rule" "iuf_from_all_icmp" { 
  security_group_id = aws_security_group.splunk-iuf.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "iuf_from_all_icmpv6" { 
  security_group_id = aws_security_group.splunk-iuf.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_autoscaling_group" "autoscaling-splunk-iuf" {
  name = "asg-splunk-iuf"
  vpc_zone_identifier  = [aws_subnet.subnet_1.id,aws_subnet.subnet_3.id,aws_subnet.subnet_3.id]
  desired_capacity   = 0
  max_size           = 0
  min_size           = 0
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id      = aws_launch_template.splunk-iuf.id
        version = "$Latest"
      }
      override {
        instance_type     = "t3a.nano"
      }
    }
  }
  depends_on = [null_resource.bucket_sync]
}

resource aws_launch_template splunk-iuf {
  name = "splunk-iuf"
  image_id                         = data.aws_ssm_parameter.linuxAmi.value
  key_name                    = aws_key_pair.master-key.key_name
  instance_type     = "t3a.nano"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 35
      volume_type = "gp2"
    }
  }
#  ebs_optimized = true
#  vpc_security_group_ids = [aws_security_group.splunk-cm.id]
  iam_instance_profile {
    name = "role-splunk-iuf_profile"
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = [aws_security_group.splunk-outbound.id,aws_security_group.splunk-iuf.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.iuf
      splunkinstanceType = var.iuf
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
  user_data = filebase64("install/user-data.txt")
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

# ***************** LB SH  **********************
resource "aws_security_group" "splunk-lbsh" {
  name = "splunk-lbsh"
  description = "Security group for Splunk LB in front of sh(s)"
  vpc_id = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-lbsh"
  }
}

resource "aws_security_group_rule" "lbsh_from_all_icmp" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbsh_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type      = "ingress"
  from_port = -1
  to_port   = -1
  protocol  = "icmpv6"
  ipv6_cidr_blocks = ["::/0"]
  description = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lbsh_from_bastion_https" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description = "allow connection to lb sh from bastion"
}

resource "aws_security_group_rule" "lbsh_from_networks_https" {
  security_group_id = aws_security_group.splunk-lbsh.id
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  cidr_blocks = ["127.0.0.10/32"]
  description = "allow https connection to lb sh from authorized networks"
}




#    ***** GLOBAL ******





#Get Linux AMI ID using SSM Parameter endpoint in region
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}


#Please note that this code expects SSH key pair to exist in default dir under 
#users home directory, otherwise it will fail

#Create key-pair for logging into EC2 in us-east-1
resource "aws_key_pair" "master-key" {
  provider   = aws.region-master
  key_name   = "mykey"
  public_key = file("~/.ssh/id_rsa.pub")
}



