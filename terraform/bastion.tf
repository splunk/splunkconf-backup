

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

