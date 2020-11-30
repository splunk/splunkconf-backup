
variable "profile" {
  type    = string
  default = "default"
}

variable "region-master" {
  type    = string
  default = "eu-west-3"
}

variable "instance-type" {
  type    = string
  default = "t3.micro"
}

variable "splunktargetenv" {
  type    = string
  default = "test"
}

variable "splunkorg" {
  type    = string
  default = "org"
}

variable "cm" {
  type    = string
  default = "cm3"
}

variable "ds" {
  type    = string
  default = "ds3"
}

variable "lm" {
  type    = string
  default = "lm3"
}

variable "sh" {
  type    = string
  default = "sh3"
}

variable "mc" {
  type    = string
  default = "mc3"
}

variable "hf" {
  type    = string
  default = "hf3"
}

variable "iuf" {
  type    = string
  default = "iuf3"
}

#DNS Configuration

#variable "dns-name" {
#  type    = string
#  default = "cloud.plouic.com."
#}

variable "dns-zone-name" {
  type    = string
  default = "cloud.plouic.com."
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
  default = ["82.64.149.57/32"]
  #default = ["127.0.0.1/32"]
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
  default = ["18.216.68.160/27","18.216.170.64/27","18.216.170.96/27","34.238.188.128/26","34.238.188.192/26","34.238.195.0/26","13.57.180.0/26","34.216.24.32/27","34.216.24.192/27","34.216.24.224/27","18.253.138.192/26","52.61.204.192/26","18.162.221.64/26","13.232.67.64/26","13.209.71.0/26","13.229.187.128/26","13.211.12.0/26","13.230.21.0/27","13.230.21.32/27","35.183.92.64/26","18.194.95.192/27","18.194.95.224/27","18.195.48.0/27","34.241.197.32/27","34.241.197.64/27","34.241.197.96/27","18.130.91.0/26","35.180.112.0/26","13.53.191.0/26","15.185.91.64/26","18.228.1.192/26","15.161.135.192/26","13.244.165.128/26"]
}
