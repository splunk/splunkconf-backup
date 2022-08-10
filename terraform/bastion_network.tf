
resource "aws_route_table" "private_route_instancegw" {
  count    = var.use_nat_gateway ? 0 : 1
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
  route {
    cidr_block = "0.0.0.0/0"
    # workaround for bastion in asg
    # as the bastion is in a asg group, the eni doesnt exist yet
    # also there is current way to attach a any as part of a asg at the moment
    # heavy workaround would be to start a lambda and add/remove the route table dynamically
    # until this, please edit here to give the eni of the bastion that does nat instance
    # this is for test env only as a prod env would use a nat gateway (price per hour make it not compelling for just testing)
    network_interface_id = "eni-024549cb31a489975"
  }
  tags = {
    Name = "Private-Region-RT"
  }
}

resource "aws_route_table" "private_route_natgw1" {
  count    = var.use_nat_gateway ? 1 : 0
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway1[0].id
  }
  tags = {
    Name = "Private-Region-RT"
  }
}


resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.subnet_priv_1.id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.subnet_priv_2.id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}
resource "aws_route_table_association" "private_3" {
  subnet_id      = aws_subnet.subnet_priv_3.id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}

