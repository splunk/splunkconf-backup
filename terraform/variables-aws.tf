# variables specific to AWS

variable "imdsv2" {
  description = "for 8.2.2+ and 8.1.5+, after configuring [imds] in server.conf to v2, you may require tokens in AWS to reduce attack surface (default=optional, set to value=required to enforce v2)"
  type    = string
  default = "optional"
}

variable "extra_tags" {
  description = "extra custom tags to add in each ASG/instances"
  type    = string
  default = ""
}
