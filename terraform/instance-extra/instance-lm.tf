
# ******************* LM *************************

resource "aws_iam_role" "role-splunk-lm" {
  name_prefix           = "role-splunk-lm-"
  force_detach_policies = true
  description           = "iam role for splunk lm"
  assume_role_policy    = file("policy-aws/assumerolepolicy-ec2.json")
  provider              = aws.region-primary

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_instance_profile" "role-splunk-lm_profile" {
  name_prefix     = "role-splunk-lm_profile"
  role     = aws_iam_role.role-splunk-lm.name
  provider = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "lm-attach-splunk-splunkconf-backup" {
  #name       = "lm-attach-splunk-splunkconf-backup"
  role = aws_iam_role.role-splunk-lm.name
  #roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-splunkconf-backup.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "lm-attach-splunk-route53-updatednsrecords" {
  #name       = "lm-attach-splunk-route53-updatednsrecords"
  role = aws_iam_role.role-splunk-lm.name
  #roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-route53-updatednsrecords.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "lm-attach-splunk-ec2" {
  #name       = "lm-attach-splunk-ec2"
  role = aws_iam_role.role-splunk-lm.name
  #roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = aws_iam_policy.pol-splunk-ec2.arn
  provider   = aws.region-primary
}

resource "aws_iam_role_policy_attachment" "lm-attach-ssm-managedinstance" {
  #name       = "lm-attach-ssm-managedinstance"
  role = aws_iam_role.role-splunk-lm.name
  #roles      = [aws_iam_role.role-splunk-lm.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  provider   = aws.region-primary
}

resource "aws_security_group_rule" "lm_from_bastion_ssh" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-bastion.id
  description              = "allow SSH connection from bastion host"
}

resource "aws_security_group_rule" "lm_from_splunkadmin-networks_ssh" {
  security_group_id = aws_security_group.splunk-lm.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow SSH connection from splunk admin networks"
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
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = var.splunkadmin-networks
  description       = "allow Webui connection from splunk admin networks"
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
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow icmp (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lm_from_all_icmpv6" {
  security_group_id = aws_security_group.splunk-lm.id
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmpv6"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "allow icmp v6 (ping, icmp path discovery, unreachable,...)"
}

resource "aws_security_group_rule" "lm_from_mc_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-mc.id
  description              = "allow MC to connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_cm_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-cm.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_idx_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-idx.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_sh_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-sh.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_ds_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-ds.id
  description              = "allow connect to instance on mgt port (rest api)"
}

resource "aws_security_group_rule" "lm_from_hf_8089" {
  security_group_id        = aws_security_group.splunk-lm.id
  type                     = "ingress"
  from_port                = 8089
  to_port                  = 8089
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.splunk-hf.id
  description              = "allow connect to instance on mgt port (rest api)"
}



