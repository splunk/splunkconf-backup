
# sent to module
variable "ssh_algorithm" {
  description = "Algorithm to use to generate key (default= RSA)  (possible values RSA, ECDSA ED25519)"
  type        = string
  default     = "RSA"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(RSA|ECDSA|ED25510)", var.ssh_algorithm))
    error_message = "value is incorrect , please read https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key and correct with possible values RSA, ECDSA ED25519"
  }
}

