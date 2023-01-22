
# also for module
variable "dns-zone-name" {
  description = "Please give here a public dns sub zone like splunk.acme.com that is cloud managed so we can publish dns entries in it as instances start and stop"
  type        = string
  default     = "splunk.acme.com"
}

variable "enable_lambda_route53" {
  description = "Enable lambda function used to scan autoscaling event received by eventbridge in the region and update route53 zone. Disable if ever you have the same lambda running in the same region (as the function should run independently in each region that you use)" 
  type        = bool
  default     = "true"
}

variable "enable-ns-glue-aws"{
  description = "true : create NS records in the zone above by calling route53, enable this if top zone is in AWS and you have credentials to update it (require dns-zone-name-top to be configured). False if managed manaually or outside this terraform"
  type= bool
  default = "true"
}

# note : because we dont manage the top zone in this TF (so we dont destroy it when we destroy this) , we have to use provisionners which is
variable "dns-zone-name-top" {
  description = "dns-zone-name should be a subzone of this one (that existing, not managed by TF and that you control in order to be able to create NS record in it (to delegate sub zone so the DNS update we do are visible from outside) (if top zone outside cloud or cant be updated by TF, please create NS in it) (certificate generations via cloud mechanisms wont work without it as this mean you cant prove the zone is yours)")
  type        = string
  default     = "could.acme.com"
}

variable "ns_ttl" {
  description = "TTL in second for NS record in top zone . Please use 86400 (1d) min except for testing"
  type = number
  default = 300
}

variable "dns-prefix" {
  description = "this setting will tell the lambda function to add this prefix to all names. This is mainly useful for testing lambda without overriding normal names in use. Use disabled to not add prefix. If tag unset, lambda- will be used as prefix (look at local.dns-prefix logic, it will the region if you dont change the locals version)"
  type        = string
  default     = "region-"
  #default = "disabled"
}

locals {
  # we have to create as local to be able to use a variable
  # comment and use the second version if you prefer specify it
  dns-prefix = var.dns-prefix == "region-" ? format("%s-", var.region-primary) : var.dns-prefix
  #dns-prefix=var.dns-prefix
}

