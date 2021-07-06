#!/bin/bash
#exec > /var/log/splunkconf-upgrade-precheck.log 2>&1

# This script is used to prepare upgrade splunk locally
# it is getting latest aws recovery and upgrade scripts and check tags BUT wont launch upgrade

# 20201011 add check for root use
# 20201102 version that does tags and script prechecks
# 20201116 extend to more files and make it more generic
# 20201117 extend version check to be more generic
# 20210202 add fallback to /etc/instance-tags
# 20210706 use cloud version when existing to avoid outdated aws version kept on s3

VERSION="20210706"

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

FILELIST="splunkconf-aws-recovery.sh splunkconf-cloud-recovery.sh splunkconf-swapme.pl splunkconf-upgrade-local.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-init.pl"

echo "splunkconf-upgrade-local-precheck  VERSION=$VERSION"



# get latest versions
for i in $FILELIST
do
  if [ -e "$localinstalldir/$i" ]; then
    # 2 versions of grep, 1 for bash, 1 for perl 
    VER=`grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i`
    echo "VER=$VER"
    if [ -z "$VER" ]; then
      echo "predownload             $i : undefined version : KO"
    else
      echo "predownload             $i $VER"
    fi
  else
    echo "script $localinstalldir/$i missing before download\n" 
  fi
  aws s3 cp $remoteinstalldir/$i  $localinstalldir --quiet
  if [ -e "$localinstalldir/$i" ]; then
    chmod +x $localinstalldir/$i
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i`
    if [ -z "$VER" ]; then
       echo "after download $i : undefined version : KO"
    else
      echo "after download OK script $i present. $VER"
    fi
  else
    echo "script $remoteinstalldir/$i is missing in s3, please add it there and relaunch this script\n"  
  fi
done
if [ -e "$localinstalldir/splunkconf-cloud-recovery.sh" ]; then
  if [ -e "$localinstalldir/splunkconf-aws-recovery.sh" ]; then
    echo "cloud recovery exist, overwriting aws version in case old one still present in install bucket"
    cp -p "$localinstalldir/splunkconf-cloud-recovery.sh" "$localinstalldir/splunkconf-aws-recovery.sh"
  fi
fi


# scripts that run as splunk and deployed in the scripts dir
localinstalldir="/opt/splunk/scripts"
mkdir -p $localinstalldir
for i in splunkconf-prepare-es-from-s3.sh
do
    if [ -e "$localinstalldir/$i" ]; then
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i`
    if [ -z "$VER" ]; then
      echo "predownload             $i : undefined version : KO"
    else
      echo "predownload             $i $VER"
    fi
  else
    echo "script $localinstalldir/$i missing before download\n"  
  fi
  aws s3 cp $remoteinstalldir/$i  $localinstalldir --quiet
  if [ -e "$localinstalldir/$i" ]; then
    # chown specific here
    chown splunk. $localinstalldir/$i
    chmod +x $localinstalldir/$i
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i`
    if [ -z "$VER" ]; then
       echo "after download : $i undefined version : KO"
    else
      echo "after download OK script $i present. $VER"
    fi
  else
    echo "script $remoteinstalldir/$i is missing in s3, please add it there and relaunch this script\n"
  fi

done

# set back to original dir
localinstalldir="/usr/local/bin"

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

