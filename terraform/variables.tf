

variable "splunkacceptlicense" {
  description = "please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html then change this variable to yes  (the license flag is passed along to Splunk Software which wont start without this)"
  type        = string
  default     = "unset-assumedno"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^(yes|no)", var.splunkacceptlicense))
    error_message = "please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html then change this variable to yes  (the license flag is passed along to Splunk Software which wont start without this)"
    # note : if explicitely set to no, the cloud pieces will be deployed but Splunk wont be configured/setup
  }
}


variable "splunkcloudmode" {
  description = "1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration (partially implemeted -> behave like 1 at the moment, 3 = byol or manual config to splunkcloud(default)"
  type        = string
  default     = "3"
}

variable "splunkconnectedmode" {
  description = "(autodetection not yet implemented, will assume connected) # 0 = auto (try to detect connectivity) (default if not set) # 1 = connected (set it if auto fail and you think you are connected) # 2 = yum only (may be via proxy or local repo if yum configured correctly) # 3 = no connection, yum disabled"
  type        = string
  default     = "0"
}

variable "instance-type-indexer-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-indexer-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-idx-a" {
  description = "disk size in G (first disk)"
  type        = number
  default     = 35
}

variable "disk-size-idx-b" {
  description = "disk size in G (second disk if used)"
  type        = number
  default     = 35
}

variable "splunkenableunifiedpartition" {
  description = "for instance with ephemeral disk whether to directly use this partition under SPLUNK_HOME (otherwise /data/vol1 is used) (default = false)"
  type        = bool
  default     = "false"
}


variable "idx-nb" {
  description = "target indexer number in ASG"
  type        = number
  default     = 3
}


variable "enable-idx-hecelb" {
  description = "whether to create ELB for IDX HEC" 
  type    = bool
  default = true
}

variable "force-idx-hecelb-private" {
  description = "whether to force ELB for IDX HEC on private network (or auto depending on other variables)" 
  type    = bool
  default = false
}

variable "hec_protocol" {
  description = "HTTP or HTTPS depending if the target being ELB listen in HTTP or HTTPS"
  type        = string
  default     = "HTTP"
}

variable "use_elb" {
  description = "whether to create ELB for HEC"
  type        = number
  default     = 1
}

variable "use_elb_ack" {
  description = "whether to create ELB for HEC with ACK (required for Kinesis Firehose)"
  type        = number
  default     = 0
}

variable "idx" {
  description = "idx name (single name to use later for ssh name)"
  type        = string
  default     = "idx"
}

variable "idxdnsnames" {
  description = "list of names to create for indexer ips (used by lambda function)"
  type        = string
  default     = "idx inputs inputs1 inputs2 inputs3 inputs4 inputs5 inputs6 inputs7 inputs8 inputs9 inputs10 inputs11 inputs12 inputs13 inputs14 inputs15 inputs16 inputs17 inputs18 inputs19"
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

variable "iuf-nb" {
  description = "target intermediate uf number in ASG"
  type        = number
  default     = 3
}

variable "instance-type-iuf-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-iuf-default" {
  type    = string
  default = "t3a.small"
}

variable "ihf-nb" {
  description = "target intermediate hf number in ASG"
  type        = number
  default     = 1
}

variable "ihf2-nb" {
  description = "target intermediate hf 2 number in ASG"
  type        = number
  default     = 1
}

variable "ihf3-nb" {
  description = "target intermediate hf 3 number in ASG"
  type        = number
  default     = 1
}

variable "instance-type-ihf-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-ihf-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-ihf" {
  description = "disk size in G for ihf"
  type        = number
  default     = 35
}

variable "smartstore_site_number" {
  description = "number of sites in multisite (this is usually 3, change this only if you really cant get a 3rd site)"
  type    = number
  default = 3
  validation {
    condition     = can(regex("[1-3]", var.smartstore_site_number))
    error_message = "Valid choices are 1(disable replication), 2 and 3 only"
  }
}

variable "cm" {
  type    = string
  default = "cm"
}

variable "instance-type-cm-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-cm-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-cm" {
  description = "disk size in G"
  type        = number
  default     = 35
}



variable "ds" {
  description = "name to give to ds instance"
  type    = string
  default = "ds"
}

variable "ds-enable" {
  type    = bool
  default = true
}

variable "instance-type-ds-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-ds-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-ds" {
  description = "disk size in G"
  type        = number
  default     = 35
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
  # cm here to colocate lm on cm
  default = "cm"
  #default = "lm"
}

variable "instance-type-lm" {
  type    = string
  default = "t3a.small"
}

variable "sh" {
  type    = string
  default = "sh"
}

variable "instance-type-sh-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-sh-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-sh" {
  description = "disk size in G"
  type        = number
  default     = 100
}

# needed so LB for SHC can know which protocol to use
variable "sh_protocol" {
  description = "protocol used on SH (HTTPS or HTTP)"
  type        = string
  default     = "HTTPS"
}

variable "mc" {
  type    = string
  default = "mc"
}

variable "mc-enable" {
  type    = bool
  default = true
}

variable "instance-type-mc-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-mc-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-mc" {
  description = "disk size in G"
  type        = number
  default     = 35
}

variable "ihf" {
  type    = string
  default = "ihf"
}

variable "hf" {
  type    = string
  default = "hf"
}

variable "instance-type-hf-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-hf-default" {
  type    = string
  default = "t3a.small"
}

variable "disk-size-hf" {
  description = "disk size in G"
  type        = number
  default     = 35
}

variable "std" {
  type    = string
  default = "std"
}

variable "instance-type-std-min" {
  type    = string
  default = "t3a.medium"
}

variable "instance-type-std-default" {
  type    = string
  default = "t3a.medium"
}

variable "disk-size-std" {
  description = "disk size in G"
  type        = number
  default     = 300
}

variable "iuf" {
  type    = string
  default = "iuf3"
}

variable "disk-size-iuf" {
  description = "disk size in G"
  type        = number
  default     = 35
}

variable "associate_public_ip" {
  description = "define if the splunk instances will have a additional public ip (still require autorizing flows on top if applicable) or just use private networks"
  type        = string
  default = "true"
  #default = "false"
}

variable "backup-retention" {
  type    = number
  default = 7
}

variable "deleteddata-retention" {
  type    = number
  default = 7
}

variable "s2days-1-ia" {
  description = "number of days for data in smartstore prefix (main) before transition to STANDARD_IA by lifecycle (30 days mini)"
  type        = number
  default     = 30
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
  default = ["notset127.0.0.1/32"]
  validation {
    # regex(...) fails if it cannot find a match
    condition     = !can(regex("notset", var.splunkadmin-networks))
    error_message = "you may want to configure splunkadmin-networks variable in order to be able to connect as admin to your instances ! If you really sure you dont need this , please use value [\"127.0.0.1/32\"]"
    # note : this is also used if going through bastion
  }
}

#variable "splunkadmin-networks-ipv6" {
#  type    = list(string)
#  default = [""]
#}

variable "trustedrestapi_to_sh" {
  description = "List of trusted networks allowed to reach SH REST API"
  type        = list(string)
  default     = ["127.0.0.12/32"]
}

variable "hec-in-allowed-networks" {
  description = "List of trusted networks allowed to send data via hec"
  type        = list(string)
  default     = ["127.0.0.12/32"]
}

variable "s2s-in-allowed-networks" {
  description = "List of trusted networks allowed to send data via S2S protocol (UF, HF,...)"
  type        = list(string)
  default     = ["127.0.0.13/32"]
}

variable "sgoutboundallprotocol" {
  description = "list of targets networks where all protocols is allowed for instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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

variable "s3_iaprefix" {
  type        = string
  description = "prefix used withing s3 ia bucket (default is ia)"
  default     = "ia"
}

variable "worker" {
  type        = string
  description = "worker name"
  default     = "worker"
}

variable "generateuserseed" {
  type        = bool
  description = "whether to generate user seed from terraform (default to false as require external helper for the moment) "
  default     = false
}

variable "splunkpwdinit" {
  type        = string
  description = "whether to generate user seed from splunkconf-init when not present (default to yes) "
  default     = "yes"
}
