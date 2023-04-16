#Create VPC in eu-west-3
resource "aws_vpc" "vpc_master" {
  count = var.create ? 1 : 0
  #provider             = aws.region-primary
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-splunk"
  }

}

#Create IGW in region
resource "aws_internet_gateway" "igw" {
  count = var.create ? 1 : 0
  #provider = aws.region-primary
  vpc_id   = aws_vpc.vpc_master[0].id
}


#Get all available AZ's in VPC for master region
data "aws_availability_zones" "azs" {
  count = var.create ? 1 : 0
  #provider = aws.region-primary
  state    = "available"
}


#Create subnet pub # 1 in vpc
resource "aws_subnet" "subnet_pub_1" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  availability_zone = element(data.aws_availability_zones.azs[0].names, 0)
  vpc_id            = aws_vpc.vpc_master[0].id
  cidr_block        = var.cidr_subnet_pub_1
}


#Create subnet pub #2  in vpc
resource "aws_subnet" "subnet_pub_2" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  vpc_id            = aws_vpc.vpc_master[0].id
  availability_zone = element(data.aws_availability_zones.azs[0].names, 1)
  cidr_block        = var.cidr_subnet_pub_2
}

#Create subnet pub #3  in vpc
resource "aws_subnet" "subnet_pub_3" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  vpc_id            = aws_vpc.vpc_master[0].id
  availability_zone = element(data.aws_availability_zones.azs[0].names, 2)
  cidr_block        = var.cidr_subnet_pub_3
}

#Create default route table in region
resource "aws_route_table" "internet_route" {
  count = var.create ? 1 : 0
  #provider = aws.region-primary
  vpc_id   = aws_vpc.vpc_master[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Master-Region-RT"
  }
}

#Overwrite default route table of VPC(Master) with our route table entries
resource "aws_main_route_table_association" "set-master-default-rt-assoc" {
  count = var.create ? 1 : 0
  #provider       = aws.region-primary
  vpc_id         = aws_vpc.vpc_master[0].id
  route_table_id = aws_route_table.internet_route[0].id
}


#Create subnet priv # 1 in vpc
resource "aws_subnet" "subnet_priv_1" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  availability_zone = element(data.aws_availability_zones.azs[0].names, 0)
  vpc_id            = aws_vpc.vpc_master[0].id
  cidr_block        = var.cidr_subnet_priv_1
}


#Create subnet priv #2  in vpc
resource "aws_subnet" "subnet_priv_2" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  vpc_id            = aws_vpc.vpc_master[0].id
  availability_zone = element(data.aws_availability_zones.azs[0].names, 1)
  cidr_block        = var.cidr_subnet_priv_2
}

#Create subnet priv #3  in vpc
resource "aws_subnet" "subnet_priv_3" {
  count = var.create ? 1 : 0
  #provider          = aws.region-primary
  vpc_id            = aws_vpc.vpc_master[0].id
  availability_zone = element(data.aws_availability_zones.azs[0].names, 2)
  cidr_block        = var.cidr_subnet_priv_3
}


resource "aws_eip" "nat_gateway" {
  count = var.use_nat_gateway ? 1 : 0
  vpc   = true
}

resource "aws_nat_gateway" "nat_gateway1" {
  count         = var.use_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat_gateway[0].id
  subnet_id     = aws_subnet.subnet_pub_1.id
  tags = {
    Name = "gw NAT"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# this moved to bastion_network as we need the bastion to be created first
#resource "aws_route_table" "private_route_instancegw" {
#  count    = var.use_nat_gateway ? 0 : 1
#  provider = aws.region-primary
#  vpc_id   = aws_vpc.vpc_master.id
#  route {
#    cidr_block = "0.0.0.0/0"
#    # workaround for bastion in asg 
#    # as the bastion is in a asg group, the eni doesnt exist yet
#    # also there is current way to attach a any as part of a asg at the moment
#    # heavy workaround would be to start a lambda and add/remove the route table dynamically
#    # until this, please edit here to give the eni of the bastion that does nat instance 
#    # this is for test env only as a prod env would use a nat gateway (price per hour make it not compelling for just testing)
#    network_interface_id = "eni-024549cb31a489975"
#  }
#  tags = {
#    Name = "Private-Region-RT"
#  }
#}

#resource "aws_route_table" "private_route_natgw1" {
#  count    = var.use_nat_gateway ? 1 : 0
#  provider = aws.region-primary
#  vpc_id   = aws_vpc.vpc_master.id
#  route {
#    cidr_block     = "0.0.0.0/0"
#    nat_gateway_id = aws_nat_gateway.nat_gateway1[0].id
#  }
#  tags = {
#    Name = "Private-Region-RT"
#  }
#}


#resource "aws_route_table_association" "private_1" {
#  subnet_id      = aws_subnet.subnet_priv_1.id
#  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
#}
#resource "aws_route_table_association" "private_2" {
#  subnet_id      = aws_subnet.subnet_priv_2.id
#  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
#}
#resource "aws_route_table_association" "private_3" {
#  subnet_id      = aws_subnet.subnet_priv_3.id
#  route_table_id = (var.use_nat_gateway ? aws_route_table.private_route_natgw1[0].id : aws_route_table.private_route_instancegw[0].id)
#}
