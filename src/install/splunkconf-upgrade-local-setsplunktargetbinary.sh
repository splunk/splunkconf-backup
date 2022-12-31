#!/bin/bash
#exec > /var/log/splunkconf-upgrade-precheck.log 2>&1

# This script is used to set/update instance tag (only, you still need to update AWS launch configuration)

VERSION="20201102"
# 20201011 add check for root use
# 20201102 initial version

# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "Exiting ! This recovery script need to be run as root !"
   exit 1
fi

if [ $# -eq 1 ]; then
  MODE=$1
  splunkbinary=$1
  echo "got splunktargetbinary=$splunkbinary from arg"
else
  splunkbinary="splunk-8.0.7-cbe73339abca-linux-2.6-x86_64.rpm"
  echo "no arg, using harcoded value  splunktargetbinary=$splunkbinary"
fi
# disabled as we just want to upgrade splunk here
#yum update -y
# just in case the AMI doesn't have it (it is preinstalled on aws ami)
# requirement access to repo that provide aws-cli (epel)
yum install aws-cli curl -y 2>&1 >/dev/null
yum install python3-pip -y 2>&1 >/dev/null
pip3 install awscli --upgrade 2>&1 >/dev/null

# setting up token (IMDSv2)
TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
# lets get the splunks3splunkinstall from instance tags
INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `
splunks3installbucket=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunks3installbucket | cut -f 5`
splunktargetbinary=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunktargetbinary | cut -f 5`
echo "before tag=$splunktargetbinary"
`aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=splunktargetbinary,Value=$splunkbinary`
splunktargetbinary=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunktargetbinary | cut -f 5`
echo "after tag=$splunktargetbinary"
remoteinstalldir="s3://$splunks3installbucket/install"
localinstalldir="/usr/local/bin"
echo "IMPORTANT : this script only change tag in the current running instance, you also need to update tag in the launch configuration to be consistent (in case the instance terminate, this would set the tag value)"
echo "end of splunkconf upgrade set tag  script"

