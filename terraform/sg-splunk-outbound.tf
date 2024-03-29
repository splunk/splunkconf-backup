
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
  cidr_blocks       = var.sgoutboundallprotocol
  description       = "allow outbound traffic (all protocols)"
}




