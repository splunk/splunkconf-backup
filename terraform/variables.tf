
variable "profile" {
  description = "profile name"
  type        = string
  default     = "default"
}

variable "region-master" {
  description = "AWS region to use (us-east-1,eu-west-3,...)"
  type        = string
  default     = "eu-west-3"
}

variable "splunktargetenv" {
  description = "environnement (min,dev,prod,...) Some other default depend on theses"
  type        = string
  default     = "test"
}

variable "splunkorg" {
  description = "prefix for apps (organization prefix)"
  type        = string
  default     = "org"
}

variable "splunkcloudmode" {
  description = "1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration (partially implemeted -> behave like 1 at the moment, 3 = byol or manual config to splunkcloud(default)"
  type        = string
  default     = "3"
}

variable "splunkconnectedmode" {
  description = "(partially implemented) # 0 = auto (try to detect connectivity) (default if not set) # 1 = connected (set it if auto fail and you think you are connected) # 2 = yum only (may be via proxy or local repo if yum configured correctly) # 3 = no connection, yum disabled"
  type        = string
  default     = "0"
}

variable "instance-type-indexer-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-indexer-default" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-idx-a" {
  description = "disk size in G (first disk)"
  type    = number
  default = 35
}

variable "disk-size-idx-b" {
  description = "disk size in G (second disk if used)"
  type    = number
  default = 35
}

variable "bastion" {
  description = "bastion / nat instance name"
  type        = string
  default     = "bastion"
}

variable "splunkcloudconfiglocation" {
  description = "universal forwarder packaged downloaded from your splunkcloud stack"
  type        = string
  default     = "local/splunkclouduf.spl"
}

variable "splunkosupdatemode" {
  description = "splunkosupdatemode=default,noreboot,disabled,updateandreboot (default means updateandreboot) (do not disable for prod unless you know what you do)"
  type        = string
  default     = "disabled"
}

variable "splunktargetbinary" {
  description = "splunk-xxxxx.rpm or auto to use the logic inside recovery script (that will choose default script version)"
  type        = string
  default     = "auto"
}

variable "splunktargetbinaryuf" {
  description = "splunk-forwarder-xxxxx.rpm or auto to use the logic inside recovery script (that will choose default script version)"
  type        = string
  default     = "auto"
}

locals {
  env                   = var.splunktargetenv
  instance-type-indexer = (local.env == "min" ? var.instance-type-indexer-min : var.instance-type-indexer-default)
}

variable "cm" {
  type    = string
  default = "cm3"
}

variable "instance-type-cm" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-cm" {
  description = "disk size in G"
  type    = number
  default = 35
}



variable "ds" {
  type    = string
  default = "ds3"
}

variable "instance-type-ds" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-ds" {
  description = "disk size in G"
  type    = number
  default = 35
}

variable "splunktar" {
  description = "set this only for multi ds where we install by tar"
  type        = string
  default     = "splunk-xxxx.tar.gz"
}

variable "dsnb" {
  type    = number
  default = 1
}

variable "lm" {
  type    = string
  default = "lm3"
}

variable "instance-type-lm" {
  type    = string
  default = "t3a.nano"
}

variable "sh" {
  type    = string
  default = "sh3"
}

variable "instance-type-sh" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-sh" {
  description = "disk size in G"
  type    = number
  default = 100
}

variable "mc" {
  type    = string
  default = "mc3"
}

variable "instance-type-mc" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-mc" {
  description = "disk size in G"
  type    = number
  default = 35
}

variable "hf" {
  type    = string
  default = "hf3"
}

variable "instance-type-hf" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-hf" {
  description = "disk size in G"
  type    = number
  default = 35
}

variable "iuf" {
  type    = string
  default = "iuf3"
}

variable "instance-type-iuf" {
  type    = string
  default = "t3a.nano"
}

variable "disk-size-iuf" {
  description = "disk size in G"
  type    = number
  default = 35
}

variable "associate_public_ip" {
  description = "define if the splunk instances will have a additional public ip (still require autorizing flows on top if applicable) or just use private networks"
  type    = string
  #default = "true"
  default = "false"
}

#DNS Configuration

#variable "dns-name" {
#  type    = string
#  default = "cloud.plouic.com."
#}

variable "dns-zone-name" {
  description = "Please give here a public dns sub zone like splunk.acme.com that is cloud managed so we can publish dns entries in it as instances start and stop"
  type    = string
  default = "cloud.plouic.com."
}

variable "dns-prefix" {
  description = "this setting will tell the lambda function to add this prefix to all names. This is mainly useful for testing lambda without overriding normal names in use. Use disabled to not add prefix. If tag unset, lambda- will be used as prefix (look at local.dns-prefix logic, it will the region if you dont change the locals version)"
  type    = string
  default = "region-"
  #default = "disabled"
}

locals {
# we have to create as local to be able to use a variable
# comment and use the second version if you prefer specify it
  dns-prefix="${var.dns-prefix == "region-" ? format("%s-",var.region-master) : var.dns-prefix}"
  #dns-prefix=var.dns-prefix
}

variable "backup-retention" {
  type    = number
  default = 7
}

variable "deleteddata-retention" {
  type    = number
  default = 7
}

variable "users-networks" {
  type    = list(string)
  default = ["127.0.0.6/32"]
}

variable "users-networks-ipv6" {
  type    = list(string)
  default = ["::1/128"]
}

variable "splunkadmin-networks" {
  type    = list(string)
  default = ["127.0.0.1/32"]
}

#variable "splunkadmin-networks-ipv6" {
#  type    = list(string)
#  default = [""]
#}

variable "hec-in-allowed-networks" {
  type    = list(string)
  default = ["127.0.0.12/32"]
}


# from https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html#using-iam-splunk
#    18.216.68.160/27, 18.216.170.64/27, 18.216.170.96/27 for US East (Ohio)

#    34.238.188.128/26, 34.238.188.192/26, 34.238.195.0/26 for US East (N. Virginia)

#    13.57.180.0/26 for US West (N. California)

#    34.216.24.32/27, 34.216.24.192/27, 34.216.24.224/27 for US West (Oregon)

#    18.253.138.192/26 for AWS GovCloud (US-East)

#    52.61.204.192/26 for AWS GovCloud (US-West)

#    18.162.221.64/26 for Asia Pacific (Hong Kong)

#    13.232.67.64/26 for Asia Pacific (Mumbai)

#    13.209.71.0/26 for Asia Pacific (Seoul)

#    13.229.187.128/26 for Asia Pacific (Singapore)

#    13.211.12.0/26 for Asia Pacific (Sydney)

#    13.230.21.0/27, 13.230.21.32/27 for Asia Pacific (Tokyo)

#    35.183.92.64/26 for Canada (Central)

#    18.194.95.192/27, 18.194.95.224/27, 18.195.48.0/27 for Europe (Frankfurt)

#    34.241.197.32/27, 34.241.197.64/27, 34.241.197.96/27 for Europe (Ireland)

#    18.130.91.0/26 for Europe (London)

#    35.180.112.0/26 for Europe (Paris)

#    13.53.191.0/26 for Europe (Stockholm)

#    15.185.91.64/26 for Middle East (Bahrain)

#    18.228.1.192/26 for South America (São Paulo)

#    15.161.135.192/26 for Europe (Milan)

#    13.244.165.128/26 for Africa (Cape Town)

variable "hec-in-allowed-firehose-networks" {
  type    = list(string)
  default = ["18.216.68.160/27", "18.216.170.64/27", "18.216.170.96/27", "34.238.188.128/26", "34.238.188.192/26", "34.238.195.0/26", "13.57.180.0/26", "34.216.24.32/27", "34.216.24.192/27", "34.216.24.224/27", "18.253.138.192/26", "52.61.204.192/26", "18.162.221.64/26", "13.232.67.64/26", "13.209.71.0/26", "13.229.187.128/26", "13.211.12.0/26", "13.230.21.0/27", "13.230.21.32/27", "35.183.92.64/26", "18.194.95.192/27", "18.194.95.224/27", "18.195.48.0/27", "34.241.197.32/27", "34.241.197.64/27", "34.241.197.96/27", "18.130.91.0/26", "35.180.112.0/26", "13.53.191.0/26", "15.185.91.64/26", "18.228.1.192/26", "15.161.135.192/26", "13.244.165.128/26"]
}
