# for module

variable "create" {
  type =bool
  default = true
}



# this is for network.tf 
# for existing vpc and networks, you probably already have these defined

variable "vpc_cidr_block" {
  description = "private cidr network for vpc"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_subnet_pub_1" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "cidr_subnet_pub_2" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "cidr_subnet_pub_3" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "cidr_subnet_priv_1" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.129.0/24"
}

variable "cidr_subnet_priv_2" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.130.0/24"
}

variable "cidr_subnet_priv_3" {
  description = "private cidr network for this subnet"
  type        = string
  default     = "10.0.131.0/24"
}

variable "use_nat_gateway" {
  description = "set this to true if you want to use nat gateway otherwise false to fall back to nat instance (for test only, read networks.tf)"
  type        = bool
  default     = true
}

# not yet implemented in networks.tf
variable "nat_gateway_ha" {
  description = "for a prod env, you probably want a nat gateway in each AZ so set this to true otherwise false. Only set this to true if use_nat_gateway is also true"
  type        = bool
  default     = true
}

