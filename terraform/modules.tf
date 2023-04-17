
# include modules

module "network" {
  create_network_module = var.create_network_module 
  source = "./modules/network"
  profile=var.profile
  splunktargetenv=var.splunktargetenv
  vpc_cidr_block=var.vpc_cidr_block
  cidr_subnet_pub_1=var.cidr_subnet_pub_1
  cidr_subnet_pub_2=var.cidr_subnet_pub_2
  cidr_subnet_pub_3=var.cidr_subnet_pub_3
  cidr_subnet_priv_1=var.cidr_subnet_priv_1
  cidr_subnet_priv_2=var.cidr_subnet_priv_2
  cidr_subnet_priv_3=var.cidr_subnet_priv_3
  use_nat_gateway=var.use_nat_gateway
  nat_gateway_ha=var.nat_gateway_ha
  dns-zone-name=var.dns-zone-name
  enable-ns-glue-aws=var.enable-ns-glue-aws
  dns-zone-name-top=var.dns-zone-name-top
  ns_ttl=var.ns_ttl
  enable_lambda_route53=var.enable_lambda_route53
  # easier to use for route53
  region=var.region-primary

  providers = {
    aws = aws.region-primary
    #aws.nested_provider_alias = aws.region-primary
  }
}


module "ssh" {
  source = "./modules/ssh"
  ssh_algorithm = var.ssh_algorithm
  providers = {
    aws = aws.region-primary
  }
}

output "splunk_ssh_key_arn" {
  value = module.ssh.splunk_ssh_key_arn
  description = "splunk_ssh awssecretsmanager arn (to be used to get the key if authorized)"
}

module "kms" {
  source = "./modules/kms"
  providers = {
    aws = aws.region-primary
  }
}
