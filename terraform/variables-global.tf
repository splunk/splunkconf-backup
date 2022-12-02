variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

variable "region-primary" {
  description = "AWS region to use (us-east-1,eu-west-3,...)"
  type        = string
  default     = "eu-west-3"
}

variable "splunktargetenv" {
  description = "environnement (min,dev,prod,...) Some other default depend on theses"
  type        = string
  default     = "test"
}

variable "splunkorg" {
  description = "prefix for apps (organization prefix)"
  type        = string
  default     = "org"
}

