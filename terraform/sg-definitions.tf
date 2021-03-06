resource "aws_security_group" "splunk-cm" {
  name        = "splunk-cm"
  description = "Security group for Splunk CM(MN)"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-cm"
  }
}

resource "aws_security_group" "splunk-sh" {
  name        = "splunk-sh"
  description = "Security group for Splunk SH"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-sh"
  }
}

resource "aws_security_group" "splunk-idx" {
  name        = "splunk-idx"
  description = "Security group for Splunk Enterprise indexers"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-idx"
  }
}

resource "aws_security_group" "splunk-lm" {
  name        = "splunk-lm"
  description = "Security group for Splunk License Master LM"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-lm"
  }
}

resource "aws_security_group" "splunk-iuf" {
  name        = "splunk-iuf"
  description = "Security group for Splunk IUF"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-iuf"
  }
}

resource "aws_security_group" "splunk-hf" {
  name        = "splunk-hf"
  description = "Security group for Splunk HF"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-hf"
  }
}

resource "aws_security_group" "splunk-ds" {
  name        = "splunk-ds"
  description = "Security group for Splunk DS"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-ds"
  }
}

resource "aws_security_group" "splunk-mc" {
  name        = "splunk-mc"
  description = "Security group for Splunk Monitoring Console MC"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "splunk-mc"
  }
}
