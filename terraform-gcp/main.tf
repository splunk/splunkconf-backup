

module "network" {
  source       = "terraform-google-modules/network/google"
  #version      = "2.5.0"
  network_name = "my-vpc-network"
  project_id   = var.project

  subnets = [
    {
      subnet_name           = "subnet-01"
      subnet_ip             = var.cidr
      subnet_region         = var.region
      google_private_access = false
    }

  ]

  secondary_ranges = {
    subnet-01 = []
  }
}


module "network_routes" {
  source       = "terraform-google-modules/network/google//modules/routes"
  #version      = "2.5.0"
  network_name = module.network.network_name
  project_id   = var.project

  routes = [
    {
      name              = "egress-internet"
      description       = "route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      tags              = "egress-inet"
      next_hop_internet = "true"

    }

  ]

}

module "network_fabric-net-firewall" {
  source                  = "terraform-google-modules/network/google//modules/fabric-net-firewall"
  #version                 = "2.5.0"
  project_id              = var.project
  network                 = module.network.network_name
  internal_ranges_enabled = true
  internal_ranges         = [var.cidr]

}


#resource "google_compute_instance" "vm_instance" {
#  name         = "terraform-instance"
#  metadata_startup_script = file("startup.sh")
#  machine_type = "f1-micro"
##  zone = var.region
#
#  boot_disk {
#    initialize_params {
#      image = "centos-cloud/centos-8"
#      #image = "centos-cloud/centos-7"
#      #image = "debian-cloud/debian-9"
#    }
#  }
#
#  network_interface {
#   network = "default"
# #   network = module.network.network_name
# #   network = module.network.module.subnets.google_compute_subnetwork.subnetwork["us-central1/subnet-01"]
#    #network = google_compute_network.vpc_network.name
#    access_config {
#    }
#  }
#  metadata = {
#    sshKeys = "${var.ssh_user}:${file(var.ssh_keys)}"
#  }
#}

resource "google_compute_firewall" "default" {
  name = "test-firewall"
  #network = google_compute_network.vpc_network.name
  network = module.network.network_name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["8000", "80", "8080", "1000-2000"]
  }

  source_tags   = ["web"]
  source_ranges = ["0.0.0.0/0"]
}
