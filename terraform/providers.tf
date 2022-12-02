
provider "aws" {
  profile = var.profile
  region  = var.region-primary
  alias   = "region-primary"
}

provider "aws" {
  profile = var.profile
  region  = var.region-secondary
  alias   = "region-secondary"
}




#provider "aws" {
#  region = var.region-secondary
#}

