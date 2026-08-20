variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

variable "splunktargetenv" {
  description = "environment (min,dev,prod,...) Some other defaults depend on these"
  type        = string
  default     = "test"
}

variable "splunkkmsarn" {
  description = "Pass-through of local.splunkkmsarn from root (null when encryption disabled)"
  type        = string
  default     = null
  nullable    = true
}

