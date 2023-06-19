resource "aws_security_group" "splunk-bastion" {
  name        = "splunk-bastion"
  description = "Security group for bastion"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-bastion"
  }
}

resource "aws_security_group" "splunk-std" {
  name        = "splunk-std"
  description = "Security group for Splunk standalone"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-std"
  }
}

resource "aws_security_group" "splunk-cm" {
  name        = "splunk-cm"
  description = "Security group for Splunk CM(MN)"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-cm"
  }
}

resource "aws_security_group" "splunk-sh" {
  name        = "splunk-sh"
  description = "Security group for Splunk SH"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-sh"
  }
}

resource "aws_security_group" "splunk-idx" {
  name        = "splunk-idx"
  description = "Security group for Splunk Enterprise indexers"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-idx"
  }
}

resource "aws_security_group" "splunk-lm" {
  name        = "splunk-lm"
  description = "Security group for Splunk License Master LM"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-lm"
  }
}

resource "aws_security_group" "splunk-iuf" {
  name        = "splunk-iuf"
  description = "Security group for Splunk IUF"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-iuf"
  }
}

resource "aws_security_group" "splunk-ihf" {
  name        = "splunk-ihf"
  description = "Security group for Splunk IHF"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-ihf"
  }
}

resource "aws_security_group" "splunk-hf" {
  name        = "splunk-hf"
  description = "Security group for Splunk HF"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-hf"
  }
}

resource "aws_security_group" "splunk-ds" {
  name        = "splunk-ds"
  description = "Security group for Splunk DS"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-ds"
  }
}

resource "aws_security_group" "splunk-mc" {
  name        = "splunk-mc"
  description = "Security group for Splunk Monitoring Console MC"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-mc"
  }
}

resource "aws_security_group" "splunk-worker" {
  name        = "splunk-worker"
  description = "Security group for Splunk Worker"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk-worker"
  }
}


