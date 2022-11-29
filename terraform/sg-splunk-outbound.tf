
# ******************** OUTBOUND  ********************
resource "aws_security_group" "splunk-outbound" {
  name        = "splunk-outbound"
  description = "Outbound Security group"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk"
  }
}

resource "aws_security_group_rule" "idx_outbound_all" {
  security_group_id = aws_security_group.splunk-outbound.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow all outbound traffic"
}

####

resource "aws_security_group" "splunk-lb-outbound" {
  name_prefix        = "splunk-lb-outbound"
  description = "Outbound Security groupi for ELB"
  vpc_id      = local.master_vpc_id
  tags = {
    Name = "splunk"
  }
}

resource "aws_security_group_rule" "lb_outbound_hecrest" {
  security_group_id = aws_security_group.splunk-lb-outbound.id
  type              = "egress"
  from_port         = 8088
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow outbound traffic for hec and rest api ports"
}

resource "aws_security_group_rule" "lb_outbound_webui" {
  security_group_id = aws_security_group.splunk-lb-outbound.id
  type              = "egress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow outbound traffic for webui port"
}





