# if we manage routing then either one of these routes need to be created
# if it is managed outside then none of these config need to be created

# Default route 0.0.0.0/0 via bastion ENI is managed at runtime by splunk-lambda-bastion-route.tf
# when use_nat_gateway = false and enable_lambda_bastion_route = true.
resource "aws_route_table" "private_route_instancegw" {
  count    = local.use_instance_gateway ? 1 : 0
  provider = aws.region-primary
  vpc_id   = local.master_vpc_id
  tags = {
    Name = "Private-Region-RT"
  }
}

resource "aws_route_table" "private_route_natgw1" {
  count    = local.use_nat_gateway ? 1 : 0
  provider = aws.region-primary
  vpc_id   = local.master_vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.nat_gateway_1_id
  }
  tags = {
    Name = "Private-Region-RT"
  }
}


resource "aws_route_table_association" "private_1" {
  count          = var.create_network_module ? 1 : 0
  subnet_id      = local.subnet_priv_1_id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}
resource "aws_route_table_association" "private_2" {
  count          = var.create_network_module ? 1 : 0
  subnet_id      = local.subnet_priv_2_id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}
resource "aws_route_table_association" "private_3" {
  count          = var.create_network_module ? 1 : 0
  subnet_id      = local.subnet_priv_3_id
  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
}

