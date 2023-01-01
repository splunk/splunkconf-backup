
variable "dns-zone-name" {
  description = "Please give here a public dns sub zone like splunk.acme.com that is cloud managed so we can publish dns entries in it as instances start and stop"
  type        = string
  default     = "splunk.acme.com"
}

variable "enable_lambda_route53" {
  type        = bool
  default     = "true"
}
