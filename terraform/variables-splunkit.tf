variable use_splunkit_tags {
  description = "whether to add splunkit tags to the provider definition"
  type = bool
  default = true
}



variable "splunkit_environment_type" {
  description = "Please define env type with one of these values (prd,non-prd,customer-prd,customer-non-prd) (default=non-prd)"
  type        = string
  default     = "non-prd"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(prd|non-prd|customer-prd|customer-non-prd)$", var.splunkit_environment_type))
    error_message = "valid values are prd,non-prd,customer-prd,customer-non-prd only"
  }
}


variable "splunkit_data_classification" {
  description = "Please define idata classification with one of these values (public,private,confidential,highly-confidential) (default=public)"
  type        = string
  default     = "public"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(public|private|confidential|highly-confidential)$", var.splunkit_data_classification))
    error_message = "valid values are public,private,confidential,highly-confidential only"
  }
}

locals {
  splunkit_tags=var.use_splunkit_tags?tomap({splunkit_environment_type=var.splunkit_environment_type,splunkit_data_classification=var.splunkit_data_classification}):null


}
