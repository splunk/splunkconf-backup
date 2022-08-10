
provider "aws" {
  profile = var.profile
  region  = var.region-master
  alias   = "region-master"
}

