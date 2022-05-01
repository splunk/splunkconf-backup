#Create VPC in eu-west-3
resource "aws_vpc" "vpc_master" {
  provider             = aws.region-master
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-splunk"
  }

}

#Create IGW in region
resource "aws_internet_gateway" "igw" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
}


#Get all available AZ's in VPC for master region
data "aws_availability_zones" "azs" {
  provider = aws.region-master
  state    = "available"
}


#Create subnet pub # 1 in vpc
resource "aws_subnet" "subnet_pub_1" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = var.cidr_subnet_pub_1
}


#Create subnet pub #2  in vpc
resource "aws_subnet" "subnet_pub_2" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
  cidr_block        = var.cidr_subnet_pub_2
}

#Create subnet pub #3  in vpc
resource "aws_subnet" "subnet_pub_3" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 2)
  cidr_block        = var.cidr_subnet_pub_3
}

#Create route table in us-east-1
resource "aws_route_table" "internet_route" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
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
  provider       = aws.region-master
  vpc_id         = aws_vpc.vpc_master.id
  route_table_id = aws_route_table.internet_route.id
}


#Create subnet priv # 1 in vpc
resource "aws_subnet" "subnet_priv_1" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = var.cidr_subnet_priv_1
}


#Create subnet priv #2  in vpc
resource "aws_subnet" "subnet_priv_2" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
  cidr_block        = var.cidr_subnet_priv_2
}

#Create subnet priv #3  in vpc
resource "aws_subnet" "subnet_priv_3" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 2)
  cidr_block        = var.cidr_subnet_priv_3
}

