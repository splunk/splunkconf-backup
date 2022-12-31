
# include modules

module "network" {
  source = "./modules/network"
}

#module "ssh" {
#  source = "./modules/ssh"
#}

module "kms" {
  source = "./modules/kms"
}
