# variables moves to a module so other modules can easily import , including when launched independently
# commented as require more abstraction to work
#module "variables" {
#  source = "./modules/variables"
#}

# include module directly
module "network" {
  source = "./modules/network"
}
