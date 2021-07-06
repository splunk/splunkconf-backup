#!/bin/bash
#exec > /var/log/splunkconf-upgrade-precheck.log 2>&1

# This script is used to prepare upgrade splunk locally
# it is getting latest aws recovery and upgrade scripts and check tags BUT wont launch upgrade

VERSION="20201103b"
# 20201011 add check for root use
# 20201102 version that does tags and script prechecks
# 20201103 initial es version
# 20201123 update for es6.4
# 20210706 update to es 6.6

# check that we are not launched
if [[ $EUID -eq 0 ]]; then
   echo "Exiting ! This script need to be run as splunk !"
   exit 1
fi

# setting up token (IMDSv2)
TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
# lets get the splunks3splunkinstall from instance tags
INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `
splunks3installbucket=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunks3installbucket | cut -f 5`
remoteinstalldir="s3://$splunks3installbucket/install"
localinstalldir="/opt/splunk/scripts"
localappsinstalldir="/opt/splunk/splunkapps"
mkdir -p $localinstalldir
mkdir -p $localappsinstalldir

if [ -z "$splunks3installbucket" ]; then
  echo "ATTENTION TAGS NOT SET in instance tags, please correct an relaunch"
  exit 1
else
  echo "Good ! Tag present and set : splunks3installbucket=$splunks3installbucket"
fi


rm $localinstalldir/installes.sh
# get latest versions
aws s3 cp $remoteinstalldir/installes.sh  $localinstalldir --quiet
chmod +x $localinstalldir/installes.sh
if [ -e "$localinstalldir/installes.sh" ]; then
  echo "installes present : OK"
else
  echo "installes.sh is NOT present in s3 install at $remoteinstalldir: KO Please upload scripts to s3 install"
fi


aws s3 cp $remoteinstalldir/apps/splunk-enterprise-security_660.spl  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/splunk-enterprise-security_660.spl" ]; then
  echo "ES install file present : OK"
else
  echo "ES install file is NOT present in s3 install at $remoteinstalldir: KO Please upload apps to s3 install"
fi

aws s3 cp $remoteinstalldir/apps/splunk-es-content-update_3240.tgz  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/splunk-es-content-update_3240.tgz" ]; then
  echo "ES Content update install file present : OK"
else
  echo "ES Content update file is NOT present in s3 install at $remoteinstalldir : KO Please upload apps to s3 install"
fi

echo "end of script, if everything is ok please run installes.sh from /opt/splunk/scripts directory (sh only)"

