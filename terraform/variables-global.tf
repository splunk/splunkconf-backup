variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

# do not use, replaced by region-primary
# we cant remove easily du to the way TF store things in state
variable "region-master" {
  description = "(legacy, please use region-primary) ) primary AWS region to use (us-east-1,eu-west-3,...)"
  type        = string
  default     = "us-east-1"
}

variable "region-primary" {
  description = "primary AWS region to use (us-east-1,eu-west-3,...)"
  type        = string
  default     = "us-east-1"
}

variable "region-secondary" {
  description = "secondary (backup) AWS region to use (us-west-1,eu-west-1,...)"
  type        = string
  default     = "us-west-1"
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
  validation {
    # regex(...) fails if it cannot find a match
    # 2 lowercase characters mini
    condition     = can(regex("^[a-z]{2,}", var.splunkorg))
    error_message = "please specify a org (lowercase characters only, minimum 2)"
  }
}

