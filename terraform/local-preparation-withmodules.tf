# this version when we use modules
# do not use the remotestate version at the same time as it would conflict


locals {
  master_vpc_id = module.network.master_vpc_id
  subnet_pub_1_id  = module.network.subnet_pub_1_id
  subnet_pub_2_id  = module.network.subnet_pub_2_id
  subnet_pub_3_id  = module.network.subnet_pub_3_id
  subnet_priv_1_id = module.network.subnet_priv_1_id
  subnet_priv_2_id = module.network.subnet_priv_2_id
  subnet_priv_3_id = module.network.subnet_priv_3_id
  nat_gateway_1_id = module.network.nat_gateway_1_id

  ssh_key_name      = module.ssh.ssh_key_name

}
