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
# 20230118 update for 7.1.0
# 20230530 update for 7.1.1
# 20230907 update for 7.2.0
# 20231220 update for 7.3.0
# 20240424 update for 7.3.1
# 20240612 update for 7.3.2
# 20240904 add version info output
# 20240913 fix version output
# 20240913 add support to give custom es and escu versions as optional arg
# 20240913 improve messages
# 20240914 fix message output
# 20241003 update output message to ease copy/paste for next steps
# 20241020 improve messages
# 20241203 improve messages
# 20250511 up 8.1.0
# 20250825 up to 8.1.1

VERSION="20250825a"

ESAPP="splunk-enterprise-security_811.spl"
ESCU="splunk-es-content-update_4330.tgz"

echo "This script $0 download/update ES files from S3 in order to prepare for ES installation/upgrade. It will try to update installes.sh script and download ES version and content update."
#echo "You are currently running with script $0 version=$VERSION"

# check that we are not launched
if [[ $EUID -eq 0 ]]; then
   echo "KO: Exiting ! This script $0 need to be run as splunk !"
   exit 1
fi

###### start

# %u is day of week , we may use this for custom purge
TODAY=`date '+%Y%m%d-%H:%M_%u'`;
ID=`date '+%s'`;
FAIL=0;

NBARG=$#
ARG1=$1
ARG2=$2

ESINSTALL="./installes.sh"
if [ $NBARG -eq 0 ]; then
  echo "no arg, using default"
  echo "This version default to ES=$ESAPP and ESCU=$ESCU"
  echo "You may provide custom versions by launching either $0 ESAPP  or $0 ESAPP ESCUAPP"
elif [ $NBARG -eq 1 ]; then
  ESAPP=$ARG1
  ESINSTALL="./installes.sh $ESAPP"
  echo "This version default to ESCU=$ESCU"
elif [ $NBARG -eq 2 ]; then
  ESAPP=$ARG1
  ESCU=$ARG2
  ESINSTALL="./installes.sh $ESAPP $ESCU"
else
#elif [ $NBARG -gt 1 ]; then
  echo "ERROR: Your command line contains too many ($#) arguments. Ignoring the extra data" 
  ESAPP=$ARG1
  ESCU=$ARG2
  ESINSTALL="./installes.sh $ESAPP $ESCU"
fi
echo "INFO: running $0 version=$VERSION with ESAPP=$ESAPP and ESCU=$ESCU (ESCU is optional)" 

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
  echo "KO: ATTENTION TAGS NOT SET in instance tags, please correct and relaunch"
  ((FAIL++))
  exit 1
else
  echo "OK: Good ! Tags present and set : splunks3installbucket=$splunks3installbucket"
fi


rm $localinstalldir/installes.sh
# get latest versions
aws s3 cp $remoteinstalldir/installes.sh  $localinstalldir --quiet
chmod +x $localinstalldir/installes.sh
if [ -e "$localinstalldir/installes.sh" ]; then
  VERINSTES=`grep VERSION= $localinstalldir/installes.sh| head -1`
  echo "OK: installes.sh present $VERINSTES"
else
  echo "KO: installes.sh is NOT present in s3 install at $remoteinstalldir:  Please upload scripts to s3 install"
  ((FAIL++))
fi


aws s3 cp $remoteappsdir/$ESAPP  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/$ESAPP" ]; then
  echo "OK: ES install file $ESAPP present at $remoteappsdir and downloaded to $localappsinstalldir for installes.sh later use"
else
  echo "KO: ES install file $ESAPP is NOT present in s3 install at $remoteappsdir: Please upload correct ES app version to s3 install or update this script is you want to use a different version"
  ((FAIL++))
fi


aws s3 cp $remoteappsdir/$ESCU  $localappsinstalldir --quiet
if [ -e "$localappsinstalldir/$ESCU" ]; then
  echo "OK: ES Content update install file $ESCU present at $remoteappsdir and downloaded to $localappsinstalldir for installes.sh later use"
else
  echo "KO: ES Content update file $ESCU is NOT present in s3 install at $remoteappsdir : Please upload correct version to s3 install or update this script to a different version. You may ignore this is if you prefer to install/upgrade ES content update from Splunk"
  # not a real fail
  #((FAIL++))
fi

if [ $FAIL -gt 0 ]; then
  echo "There were ${FAIL} fail condition(s) detected, please review messages, fix and rerun script before proceeding to installation step. If you are really sure, you may still continue with esinstall steps by running ${ESINSTALL} !"
  PROCEED="N"
  #exit 1
else
  echo "OK: all looks good to continue to next step"
  PROCEED="Y"
  echo "INFO: please run as user splunk  ${ESINSTALL} from /opt/splunk/scripts directory (sh only) to install/upgrade ES and run es setup" 
fi 

