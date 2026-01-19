# variables specific to AWS

variable "imdsv2" {
  description = "for 8.2.2+ and 8.1.5+, after configuring [imds] in server.conf to v2, you may require tokens in AWS to reduce attack surface (default=required which is more secure, set to value=disable to allow v1)"
  type        = string
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(required|optional)", var.imdsv2))
    error_message = "please set imdsv2 to required (default, more secure) or optional (allow v1 or v2)"
  }
  default     = "required"
}

variable "extra_default_tags" {
  description = "extra default tags to add at provider level (can be used for billing purpose)"
  type        = map(any)
  default     = { Type = "Splunk", Project = "Splunk" }
}

#variable "usekms" {
#  description = "set this to 1  if you plan  to use kms" 
#  type    = number
#  default = "0"
#}

variable "kmsid" {
  description = "specify kms id if you use kms with customer supplied key (sse-kms)"
  type        = string
  default     = "splunks3kms"
}

variable "idxasg_cooldown" {
  description = "time in second after a scaling activity iin asg idx occur before another scaling activity can start "
  type        = number
  default     = 60
}

variable "objectlock-backup" {
  description = "Whether to enable object lock feature for S3 backup bucket (need to be choosen at bucket creation time) "
  type        = bool
  default     = "true"
}

variable "objectlock-backup-days" {
  description = "number of retention days enforced for objectlock backups"
  type        = number
  default     = 7
}

# COMPLIANCE cant be overwritten
# GOVERNANCE can with special rights, see https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html and https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock-overview.html
variable "objectlock-backup-mode" {
  description = "objectlock backups mode : COMPLIANCE or GOVERNANCE"
  type        = string
  default     = "COMPLIANCE"
}

variable "enable-s3-normal-replication-backup" {
  description = "Whether to replicate s3 backup from primary to secondary region (you may want to disable if failed over and secondary is more fresh)"
  type        = bool
  default     = "false"
}

variable "enable-s3-reverse-replication-backup" {
  description = "Whether to replicate s3 backup from secondary region to primary (make sure you understand what it means if you set this, bad things could happen otherwise !)"
  type        = bool
  default     = "false"
}

variable "enable-fss3-policy" {
  description = "Whether to enable fs s3 policy which will require principal variable to be configured correctly (default : false) "
  type        = bool
  default     = "false"
}

#variable "fs_s3_principal" {
#  description = "AWS principal to authorize for FS S3 (example [ \"1111111111\",\"22222222222\" ] ) "
#  type    = string
#  default = ""
#  # FIXME : add condition to fail if enable is true and this variable empty
#}

variable "fs_s3_principals" {
  description = "(not yet used, need to switch to templatefile in tf before.) List of AWS principals to authorize for FS S3 (example [ \"1111111111\",\"22222222222\" ] ) "
  type        = list(string)
  default     = [""]
  # example [ "1111111111","22222222222" ]
  # FIXME : add condition to fail if enable is true and this variable empty
}

variable "enable-al2023" {
  description = "Whether to use al2023 instead of AWS2 AMI (if nit in custom mode)"
  type        = bool
  default     = "true"
}

variable "enable-customami" {
  description = "Whether to use custom ami (will take over the default one usage) (you need to set a correct ssmamicustompath in that case)"
  type        = bool
  default     = "false"
}

variable "ssmamicustompath" {
  description = "custom path for ami (rh like only)"
  type        = string
  default     = "notset"
}

variable "s3_bucket_1" {
  description = "s3 bucket to access"
  type        = string
  default     = "notset"
}

variable "s3_prefix_1" {
  description = "s3 prefix to access"
  type        = string
  default     = "notset"
}



