# variables moves to a module so other modules can easily import , including when launched independently
module "variables" {
  source = "./modules/variables"
}
