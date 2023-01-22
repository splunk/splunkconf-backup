
locals {
  # we have to create as local to be able to use a variable
  # comment and use the second version if you prefer specify it
  dns-prefix = var.dns-prefix == "region-" ? format("%s-", var.region-primary) : var.dns-prefix
  #dns-prefix=var.dns-prefix
}

