# you can override this with a s3 remote backend

data "terraform_remote_state" "ssh" {
  backend = "local"
  config = {
    path = "./modules/ssh/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "./modules/network/terraform.tfstate"
  }
}
