variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

variable "splunktargetenv" {
  description = "environnement (min,dev,prod,...) Some other default depend on theses"
  type        = string
  default     = "test"
}

