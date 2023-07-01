terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
   github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  #  profile = var.profile
  region = var.region-primary
  alias  = "region-primary"
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  #  profile = var.profile
  region = var.region-secondary
  alias  = "region-secondary"
  default_tags {
    tags = local.default_tags
  }
}




#provider "aws" {
#  region = var.region-secondary
#}

# legacy 
provider "aws" {
  #  profile = var.profile
  region = var.region-primary
  alias  = "region-master"
  default_tags {
    tags = local.default_tags
  }
}

