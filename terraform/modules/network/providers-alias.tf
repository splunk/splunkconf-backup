# force the provider to be passed via module

terraform {
  required_providers {
    aws.nested_provider_alias = {
      source  = "hashicorp/aws"
      #version = "~> 4.0"
    }
  }
}

