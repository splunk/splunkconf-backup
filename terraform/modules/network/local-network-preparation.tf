locals {
  use_nat_gateway = ( var.create_network_module ? var.use_nat_gateway : false )
}
