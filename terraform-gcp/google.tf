provider "google" {
  credentials = file("terraform-key.json")
  project     = var.project
  region      = var.region
  zone        = "us-central1-c"
}

#data "google_compute_default_service_account" "default" {
#}

#output "default_account" {
#  value = data.google_compute_default_service_account.default.email
#}

resource "google_project_service" "project" {
  project = var.project
  service = "iam.googleapis.com"

  disable_dependent_services = true
}

