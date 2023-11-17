#terraform {
#  required_providers {
#    github = {
#      source  = "integrations/github"
#      version = "~> 5.0"
#    }
#  }
#}

# Configure the GitHub Provider
provider "github" {
 token = var.ghtoken # or `GITHUB_TOKEN
 owner = var.ghowner
 read_delay_ms = 1000
}

# Add a user to the organization
#resource "github_membership" "membership_for_user_x" {
#  # ...
#}
