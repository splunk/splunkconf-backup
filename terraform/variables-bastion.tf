# variables specific to bastion

variable "use_doublebastion" {
  description = "set to yes value if you go through a external bastion"
  type        = string
  default     = "no"
}

variable "bastion2host" {
  description = "bastion2 hostname"
  type        = string
  default     = "notset"
}

variable "keypath" {
  description = "path where priv keys are"
  type        = string
  default     = "."
}

variable "privkeynameforbastion2" {
  description = "priv key name for bastion2"
  type        = string
  default     = "id_rsa.priv"
}

variable "bastion2user" {
  description = "user login for bastion2"
  type        = string
  default     = "ec2-user"
}

variable "bastionuser" {
  description = "user login for bastion"
  type        = string
  default     = "ec2-user"
}

variable "hostuser" {
  description = "user login for hosts"
  type        = string
  default     = "ec2-user"
}


