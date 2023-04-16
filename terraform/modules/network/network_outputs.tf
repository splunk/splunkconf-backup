
output "master_vpc_id" {
  description = "Masgter VPC id"
  value       = aws_vpc.vpc_master.id
}

output "dnszone_id" {
  description = "Route53 DNS Zone id"
  value       = aws_route53_zone.dnszone.id
}

output "subnet_pub_1_id" {
  description = "Subnet Pub 1 id"
  value = aws_subnet.subnet_pub_1.id
}

output "subnet_pub_2_id" {
  description = "Subnet Pub 2 id"
  value = aws_subnet.subnet_pub_2.id
}

output "subnet_pub_3_id" {
  description = "Subnet Pub 3 id"
  value = aws_subnet.subnet_pub_3.id
}

output "subnet_priv_1_id" {
  description = "Subnet Priv 1 id"
  value = aws_subnet.subnet_priv_1.id
}

output "subnet_priv_2_id" {
  description = "Subnet Priv 2 id"
  value = aws_subnet.subnet_priv_2.id
}

output "subnet_priv_3_id" {
  description = "Subnet Priv 3 id"
  value = aws_subnet.subnet_priv_3.id
}

output "nat_gateway_1_id" {
  description = "NAT gateway 1 id"
  value = (var.use_nat_gateway ? aws_nat_gateway.nat_gateway1[0].id : "0" )
}
