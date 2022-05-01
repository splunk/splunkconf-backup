
# this is for network.tf 
# for iexsiting vpc and networks, you probably already have these defined

variable "vpc_cidr_block" {
  description = "private cidr network for vpc"
  type    = string
  default = "10.0.0.0/16"
}

variable "cidr_subnet_pub_1" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.1.0/24"
}

variable "cidr_subnet_pub_2" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.2.0/24"
}

variable "cidr_subnet_pub_3" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.3.0/24"
}

variable "cidr_subnet_priv_1" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.129.0/24"
}

variable "cidr_subnet_priv_2" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.130.0/24"
}

variable "cidr_subnet_priv_3" {
  description = "private cidr network for this subnet"
  type    = string
  default = "10.0.131.0/24"
}

