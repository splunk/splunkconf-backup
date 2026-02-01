# for kms

variable "deletion_window_in_days" {
  type        = number
  default     = 30
}

variable "rotation_period_in_days" {
  type        = number
  default     = 365
}

variable "enable_key_rotation" {
  type        = bool
  default     = "true"
}

