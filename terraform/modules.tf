
# include modules

module "network" {
  source = "./modules/network"
  vpc_cidr_block=var.vpc_cidr_block
  cidr_subnet_pub_1=var.cidr_subnet_pub_1
  cidr_subnet_pub_2=var.cidr_subnet_pub_2
  cidr_subnet_pub_3=var.cidr_subnet_pub_3
  cidr_subnet_priv_1=var.cidr_subnet_priv_1
  cidr_subnet_priv_2=var.cidr_subnet_priv_2
  cidr_subnet_priv_3=var.cidr_subnet_priv_3
  use_nat_gateway=var.use_nat_gateway
  nat_gateway_ha=var.nat_gateway_ha

 providers = {
   aws.nested_provider_alias = aws.region-primary
 }
}


module "ssh" {
  source = "./modules/ssh"
}

module "kms" {
  source = "./modules/kms"
}
