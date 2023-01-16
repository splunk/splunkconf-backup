
# also for module
variable "dns-zone-name" {
  description = "Please give here a public dns sub zone like splunk.acme.com that is cloud managed so we can publish dns entries in it as instances start and stop"
  type        = string
  default     = "splunk.acme.com"
}

variable "enable_lambda_route53" {
  description = "Enable lambda function used to scan autoscaling event received by eventbridge in the region and update route53 zone. Disable if ever you have the same lambda running in the same region (as the function should run independently in each region that you use) 
  type        = bool
  default     = "true"
}

# only for top 

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

