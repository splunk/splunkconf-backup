
variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

variable "region-master" {
  description = "AWS region to use (us-east-1,eu-west-3,...)"
  type        = string
  default     = "eu-west-3"
}
