#!/bin/bash -x
exec > /var/log/splunkconf-upgrade.log 2>&1

# This script is used to upgrade splunk locally without having to destroy the instance completely
# it is getting latest aws recovery script and call it with upgrade arg
# 20201011 add check for root use
# 20210202 add fallback to /etc/instance-tags
 
VERSION="20210202"

# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "Exiting ! This recovery script need to be run as root !"         
   exit 1
fi 

# disabled as we just want to upgrade splunk here 
#yum update -y
# just in case the AMI doesn't have it (it is preinstalled on aws ami)
# requirement access to repo that provide aws-cli (epel)
yum install aws-cli curl -y
# aws recommended for rh8 
dnf install python3-pip -y || yum install python3-pip -y
pip3 install awscli --upgrade

# setting up token (IMDSv2)
TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
# lets get the splunks3splunkinstall from instance tags
INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `
splunks3installbucket=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunks3installbucket | cut -f 5`
if [ -z "$splunks3installbucket" ]; then
  echo "ATTENTION TAGS NOT SET in instance tags, please correct and relaunch"
  INSTANCEFILE="/etc/instance-tags"
  if [ -e "$INSTANCEFILE" ]; then
    chmod 644 $INSTANCEFILE
    # including the tags for use in this script
    . $INSTANCEFILE
  else
    echo "ERROR : no instance tags file at $INSTANCEFILE"
    exit 1
  fi
else
  echo "Good ! Tag present and set : splunks3installbucket=$splunks3installbucket"
fi
remoteinstalldir="s3://$splunks3installbucket/install"
localinstalldir="/usr/local/bin"
mkdir -p $localinstalldir
# get latest version 
aws s3 cp $remoteinstalldir/splunkconf-aws-recovery.sh  $localinstalldir --quiet
if [ -e "$localinstalldir/splunkconf-aws-recovery.sh" ]; then
  chmod +x $localinstalldir/splunkconf-aws-recovery.sh
  # need to pass upgrade argument,  for the rest we will use contextual data from tags
  . $localinstalldir/splunkconf-aws-recovery.sh upgrade 
else
  echo "splunkconf-aws-recovery.sh could not be downloaded, please check that it is on s3 install , that iam are set to autorize and tags for splunks3installbucket is set" 
fi
echo "end of splunkconf upgrade script"
