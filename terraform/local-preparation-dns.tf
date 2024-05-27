
locals {
  # we have to create as local to be able to use a variable
  # comment and use the second version if you prefer specify it
  dns-prefix = local.dns-prefix2 == "region-" ? format("%s-", var.region-primary) : local.dns-prefix2
  dns-prefix2 = var.dns-prefix == "disabled" ? "" : var.dns-prefix
  #dns-prefix=var.dns-prefix
}

