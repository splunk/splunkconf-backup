# variables specific to AWS

variable "imdsv2" {
  description = "for 8.2.2+ and 8.1.5+, after configuring [imds] in server.conf to v2, you may require tokens in AWS to reduce attack surface (default=optional, set to value=required to enforce v2)"
  type        = string
  default     = "optional"
}

variable "extra_tags" {
  description = "extra custom tags to add in each ASG/instances"
  type        = string
  default     = ""
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



                
