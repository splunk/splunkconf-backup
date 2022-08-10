
variable "project" {
  default = "myproject"
}

variable "region" {
  default = "us-central1"
}

variable zone {
  default = "us-central1-c"
}

variable zoneslist {
  default = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"]
}

variable "cidr" {
  default = "10.0.0.0/16"
}

variable "ssh_user" {
  default = "centos"
}

variable "ssh_keys" {
  default = "~/.ssh/id_rsa.pub"
}

variable "gcpdnszoneid" {
  default = "acme.com"
}

variable "gcposimage" {
  #default = "projects/centos-cloud/global/images/centos-stream-8-v20220519"
# project centos-cloud
  default = "family/centos-stream-9"
}

# for Local SSD's
variable "idx_disk_count" {
  description = "Number of disks to attach when using local-ssd (each volume 375 GB) (current GCP max = 24 ie 9000G)"
  type = number
  default = 2
}
