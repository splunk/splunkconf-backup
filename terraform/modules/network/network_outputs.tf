
output "master_vpc_id" {
  description = "Master VPC id"
  value       = var.create_network_module ? aws_vpc.vpc_master[0].id : var.vpc_primary_id_import
}

output "dnszone_id" {
  description = "Route53 DNS Zone id"
  value       = aws_route53_zone.dnszone.id
}

output "subnet_pub_1_id" {
  description = "Subnet Pub 1 id"
  value = var.create_network_module ? aws_subnet.subnet_pub_1[0].id : var.cidr_subnet_pub_1_id_import
}

output "subnet_pub_2_id" {
  description = "Subnet Pub 2 id"
  value = var.create_network_module ? aws_subnet.subnet_pub_2[0].id : var.cidr_subnet_pub_2_id_import
}

output "subnet_pub_3_id" {
  description = "Subnet Pub 3 id"
  value = var.create_network_module ? aws_subnet.subnet_pub_3[0].id : var.cidr_subnet_pub_3_id_import
}

output "subnet_priv_1_id" {
  description = "Subnet Priv 1 id"
  value = var.create_network_module ? aws_subnet.subnet_priv_1[0].id : var.cidr_subnet_priv_1_id_import
}

output "subnet_priv_2_id" {
  description = "Subnet Priv 2 id"
  value = var.create_network_module ? aws_subnet.subnet_priv_2[0].id : var.cidr_subnet_priv_2_id_import
}

output "subnet_priv_3_id" {
  description = "Subnet Priv 3 id"
  value = var.create_network_module ? aws_subnet.subnet_priv_3[0].id : var.cidr_subnet_priv_3_id_import
}

output "nat_gateway_1_id" {
  description = "NAT gateway 1 id"
  value = (local.use_nat_gateway ? aws_nat_gateway.nat_gateway1[0].id : "0" )
}
