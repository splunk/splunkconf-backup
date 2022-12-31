#!/bin/bash
#exec > /var/log/splunkconf-upgrade-precheck.log 2>&1

# This script is used to prepare upgrade splunk locally
# it is getting latest aws recovery and upgrade scripts and check tags BUT wont launch upgrade

# 20201011 add check for root use
# 20201102 version that does tags and script prechecks
# 20201103 initial es version
# 20201123 update for es6.4
# 20210706 update to es 6.6
# 20211104 update for 6.6.2 and add variables for versions
# 20211217 update for 7.0.0
# 20220325 update for 7.0.1
# 20220815 add remoteappsdir var and improve error messages
# 20221009 update for 7.0.2

VERSION="20221009"

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
remoteappsdir="${remoteinstalldir}/apps"
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

ESAPP="splunk-enterprise-security_702.spl"

aws s3 cp $remoteappsdir/$ESAPP  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/$ESAPP" ]; then
  echo "ES install file $ESAPP present : OK"
else
  echo "ES install file $ESAPP is NOT present in s3 install at $remoteappsdir: KO Please upload correct ES app version to s3 install or update this script is you want to use a different version"
fi

ESCU="splunk-es-content-update_3500.tgz"

aws s3 cp $remoteappsdir/$ESCU  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/$ESCU" ]; then
  echo "ES Content update install file $ESCU present : OK"
else
  echo "ES Content update file $ESCU is NOT present in s3 install at $remoteappsdir : KO Please upload correct version to s3 install or update this script to a different version"
fi

echo "end of script, if everything is ok please run as splunk installes.sh from /opt/splunk/scripts directory (sh only)"

