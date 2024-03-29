# variables specific to bastion

variable "use_doublebastion" {
  description = "set to yes value if you go through a external bastion"
  type        = string
  default     = "no"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(yes|no)$", var.use_doublebastion))
    error_message = "valid values are yes and no only"
  }
}

variable "bastion2host" {
  description = "bastion2 hostname"
  type        = string
  default     = "notset"
}

variable "keypath" {
  description = "path where priv keys are"
  type        = string
  default     = "../helpers"
}

variable "keybastion2path" {
  description = "path where priv keys are"
  type        = string
  default     = "~/.ssh"
}

variable "privkeynameforbastion2" {
  description = "priv key name for bastion2"
  type        = string
  default     = "id_rsa"
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

variable "bastionstrichostchecking" {
  description = "whether to use strict host checking there (yes,no or accept-new)"
  type        = string
  default     = "accept-new"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(yes|no|accept-new)$", var.bastionstrichostchecking))
    error_message = "valid values are yes,no and accept-new only"
  }
}

variable "hostuser" {
  description = "user login for hosts"
  type        = string
  default     = "ec2-user"
}


