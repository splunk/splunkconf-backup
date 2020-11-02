#!/bin/bash
#exec > /var/log/splunkconf-upgrade-precheck.log 2>&1

# This script is used to prepare upgrade splunk locally
# it is getting latest aws recovery and upgrade scripts and check tags BUT wont launch upgrade

VERSION="20201102"
# 20201011 add check for root use
# 20201102 version that does tags and script prechecks

# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "Exiting ! This recovery script need to be run as root !"
   exit 1
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
remoteinstalldir="s3://$splunks3installbucket/install"
localinstalldir="/usr/local/bin"
mkdir -p $localinstalldir

echo "splunkconf-upgrade-local-precheck  VERSION=$VERSION"
echo "version check before download"
VER=`grep ^VERSION $localinstalldir/splunkconf-upgrade-local.sh`
echo "splunkconf-upgrade-local $VER"

VER=`grep ^VERSION $localinstalldir/splunkconf-aws-recovery.sh`
echo "splunkconf-upgrade-local $VER"

if [ -z "$splunks3installbucket" ]; then
  echo "ATTENTION TAGS NOT SET in instance tags, please correct an relaunch"
  exit 1
else
  echo "Good ! Tag present and set : splunks3installbucket=$splunks3installbucket"
fi


# get latest versions
aws s3 cp $remoteinstalldir/splunkconf-upgrade-local.sh  $localinstalldir --quiet
chmod +x $localinstalldir/splunkconf-upgrade-local.sh
aws s3 cp $remoteinstalldir/splunkconf-aws-recovery.sh  $localinstalldir --quiet
chmod +x $localinstalldir/splunkconf-aws-recovery.sh

if [ -e "$localinstalldir/splunkconf-upgrade-local.sh" ]; then
  echo "splunkconf-upgrade-local present : OK"
else
  echo "splunkconf-upgrade-local is NOT present in s3 install : KO Please upload scripts to s3 install"
fi

if [ -e "$localinstalldir/splunkconf-aws-recovery.sh" ]; then
  echo "splunkconf-aws-recovery.sh present : OK"
else
  echo "splunkconf-aws-recovery.sh is NOT present in s3 install : KO Please upload scripts to s3 install"
fi

echo "version check after download"
VER=`grep ^VERSION $localinstalldir/splunkconf-upgrade-local.sh`
echo "splunkconf-upgrade-local $VER"

VER=`grep ^VERSION $localinstalldir/splunkconf-aws-recovery.sh`
echo "splunkconf-upgrade-local $VER"

if [ -z "$splunktargetbinary" ]; then
  splunktargetbinary=`grep ^splbinary $localinstalldir/splunkconf-aws-recovery.sh | cut -d"\"" -f2`
  echo "ATTENTION splunktargetbinary not SET in instance tags, version used will be the one hardcoded in script : $splunktargetbinary"
else
  echo "splunksplunktargetbinary=$splunktargetbinary"
fi
echo "checking RPM is present in s3 install"
aws s3 cp $remoteinstalldir/$splunktargetbinary /tmp --quiet
if [ -e "/tmp/$splunktargetbinary" ]; then
  echo "RPM $splunktargetbinary is present in s3 install : OK"
else
  echo "RPM $splunktargetbinary is NOT present in s3 install : KO Please upload RPM or check tag value"
fi

# we are updating ourselve, last action as it may break here

aws s3 cp $remoteinstalldir/splunkconf-upgrade-local-precheck.sh  $localinstalldir --quiet
chmod +x $localinstalldir/splunkconf-upgrade-local-precheck.sh
echo "end of splunkconf upgrade precheck script"

