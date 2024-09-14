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
# 20220326 add zstd package install
# 20221205 check for splunkacceptlicense tag and ask for it if not present
# 20230118 format messages to start with OK or KO
# 20230118 typo fix in test
# 20230622 enable disconnectedmode logic
# 20230622 add logic to autoupdate at start 
# 20230622 improve logging messages
# 20230626 rework multiple version log case
# 20230626 improve logging also for es precheck
# 20230626 improve messages 
# 20240424 improve messages and add condition for log4j hotfix and AL2023
# 20240424 add disk space output
# 20240424 update splunktargetbinary to only check for presence (avoid failures on disk space) and improve message when tag set to auto
# 20240424 add detection for curl-minimal package to clean up output when this package is deploeyed (like AL2023)
# 20240914 fix splunktargetbinary auto checking wrong file -> force cloud version

VERSION="20240914a"

# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "Exiting ! This recovery script $0 need to be run as root !"
   exit 1
fi

PROG=$0

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
function check_cloud() {
  cloud_type=0
  response=$(curl -fs -m 5 -H "Metadata-Flavor: Google" ${METADATA_URL})
  if [ $? -eq 0 ]; then
    echo 'GCP instance detected'
    cloud_type=2
  # old aws hypervisor
  elif [ -f /sys/hypervisor/uuid ]; then
    if [ `head -c 3 /sys/hypervisor/uuid` == "ec2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # newer aws hypervisor (test require root)
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "ec2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # if detection not yet successfull, try fallback method
  if [[ $cloud_type -eq "0" ]]; then 
    # Fallback check of http://169.254.169.254/. If we wanted to be REALLY
    # authoritative, we could follow Amazon's suggestions for cryptographically
    # verifying their signature, see here:
    #    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
    # but this is almost certainly overkill for this purpose (and the above
    # checks of "EC2" prefixes have a higher false positive potential, anyway).
    #  imdsv2 support : TOKEN should exist if inside AWS even if not enforced   
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
    if [ -z ${TOKEN+x} ]; then
      # TOKEN NOT SET , NOT inside AWS
      cloud_type=0
    elif $(curl --silent -m 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone) ; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
}

# splunkconnectedmode   (tag got from instance)
# 0 = auto (try to detect connectivity) (default if not set)
# 1 = connected (set it if auto fail and you think you are connected)
# 2 = yum only (may be via proxy or local repo if yum configured correctly)
# 3 = no connection, yum disabled

# why we need this -> cloud context may vary depending on various compliance requirements
# the full connected world -> easier 
set_connectedmode () {
  if [ -z ${splunkconnectedmode+x} ]; then
     # variable not set -> default is auto
     echo "splunkconencted unset, using 0"
     splunkconnectedmode=0
  fi
  # FIXME here add logic for auto detect 
  # for now assuming connected
  if (( splunkconnectedmode == 0 )); then
    echo "INFO: splunkconnectedmode=auto -> assuming fully connected mode"
    splunkconnectedmode=1
  elif (( splunkconnectedmode == 1 )); then
    echo "INFO: splunkconnectmode =  fully connected"
  elif (( splunkconnectedmode == 2 )); then
    echo "INFO: splunkconnectmode was set to download via package manager (ie yum,...) only"
  elif (( splunkconnectedmode == 3 )); then
    echo "INFO: splunkconnectmode was set to no connection. Assuming you have deployed all the requirement yourself"
  else
    echo "WARNING: splunkconnectmode=${splunkconnectedmode} is not a expected value, falling back to fully connected"
    splunkconnectedmode=1
  fi
  echo "INFO: splunkconnectedmode=${splunkconnectedmode}"
}



#PACKAGELIST="wget perl java-1.8.0-openjdk nvme-cli lvm2 curl gdb polkit tuned zstd"
PACKAGELIST="aws-cli python3-pip zstd"
if [ $( rpm -qa | grep -ic curl-minimal  ) -gt 0 ]; then
        echo "curl-minimal package detected"
else
        echo "curl-minimal not detected, assuming curl"
        PACKAGELIST="${PACKAGELIST} curl"
fi

get_packages () {
  #echo "DEBUG: splunkconnectedmode=$splunkconnectedmode"
  if (( splunkconnectedmode == 3 )); then
    echo "INFO : not connected mode, package installation disabled. Would have done yum install --setopt=skip_missing_names_on_install=True ${PACKAGELIST} -y followed by pip3 install awscli --upgrade"
  else 
    # perl needed for swap (regex) and splunkconf-init.pl
    # openjdk not needed by recovery itself but for app that use java such as dbconnect , itsi...
    # wget used by recovery
    # curl to fetch files
    # gdb provide pstack which may be needed to collect things for Splunk support

    if ! command -v yum &> /dev/null
    then
      echo "FAIL : yum command could not be found, not RH like distribution , not fully implemented/tested at the moment, stopping here " >> /var/log/splunkconf-cloud-recovery-info.log
      exit 1
    fi

    yum install --setopt=skip_missing_names_on_install=True  ${PACKAGELIST}  -y
    if [ $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
      echo "distribution whithout log4j hotfix, no need to try disabling it"
    else
      # disable as scan in permanence and not needed for splunk
      echo "trying to disable log4j hotfix, as perf hirt and not needed for splunk"
      systemctl stop log4j-cve-2021-44228-hotpatch
      systemctl disable log4j-cve-2021-44228-hotpatch
    fi
    # one yum command so yum can try to download and install in // which will improve recovery time
    pip3 install awscli --upgrade 2>&1 >/dev/null
  fi #splunkconnectedmode
}




# setting up token (IMDSv2)
TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
# lets get the splunks3splunkinstall from instance tags
INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `
splunks3installbucket=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunks3installbucket | cut -f 5`
splunktargetbinary=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunktargetbinary | cut -f 5`
splunkacceptlicense=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunkacceptlicense | cut -f 5`
splunkconnectedmode=`aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | grep splunkconnectemode | cut -f 5`
if [ -z "$splunks3installbucket" ]; then
  echo "KO: ATTENTION TAGS NOT SET in instance tags, please correct and relaunch"
  INSTANCEFILE="/etc/instance-tags"
  if [ -e "$INSTANCEFILE" ]; then
    chmod 644 $INSTANCEFILE
    # including the tags for use in this script
    . $INSTANCEFILE
  else
    echo "ERROR : no instance tags file at $INSTANCEFILE"
    exit 1
  fi
elif [ -z "$splunkacceptlicense" ]; then
  echo "KO: ATTENTION please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html then add splunkaccceptlicense=yes tag to this instance metadata and relaunch" 
  exit 1
else
  echo "OK: Good ! Tag present and set : splunks3installbucket=$splunks3installbucket, splunkacceptlicense=$splunkacceptlicense"
fi
remoteinstalldir="s3://$splunks3installbucket/install"
localinstalldir="/usr/local/bin"
mkdir -p $localinstalldir

set_connectedmode

echo "splunkconf-upgrade-local-precheck PROG=$PROG VERSION=$VERSION"


if [[ "$PROG" =~ .*2\.sh$ ]]; then
  echo "we are already running latest version ($VERSION), continuing"
  echo "replacing in place version (for next time)"
  cp -p $localinstalldir/splunkconf-upgrade-local-precheck-2.sh $localinstalldir/splunkconf-upgrade-local-precheck.sh
else
  # we are updating ourselve, it may break if done in place so we use another path
  aws s3 cp $remoteinstalldir/splunkconf-upgrade-local-precheck.sh  $localinstalldir/splunkconf-upgrade-local-precheck-2.sh --quiet
  if [ -e "$localinstalldir/splunkconf-upgrade-local-precheck-2.sh" ]; then 
    echo "launching latest version via $localinstalldir/splunkconf-upgrade-local-precheck-2.sh"
    chmod +x $localinstalldir/splunkconf-upgrade-local-precheck-2.sh
    $localinstalldir/splunkconf-upgrade-local-precheck-2.sh
    exit 0
  else
    echo "KO: Missing $remoteinstalldir/splunkconf-upgrade-local-precheck.sh (or permission issue) -> Exiting, please correct and relaunch"
    exit 1
  fi
fi

# disabled as we just want to upgrade splunk here
#yum update -y
# just in case the AMI doesn't have it (it is preinstalled on aws ami)
# requirement access to repo that provide aws-cli (epel)
#yum install --setopt=skip_missing_names_on_install=True aws-cli curl python3-pip zstd -y 2>&1 >/dev/null
#yum install python3-pip -y 2>&1 >/dev/null
#pip3 install awscli --upgrade 2>&1 >/dev/null
get_packages

# initiaze counters
total=0
nbok=0
nbko=0

FILELIST="splunkconf-aws-recovery.sh splunkconf-cloud-recovery.sh splunkconf-swapme.pl splunkconf-upgrade-local.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-init.pl"
# get latest versions
for i in $FILELIST
do
  ((total+=1))
  if [ -e "$localinstalldir/$i" ]; then
    # 2 versions of grep, 1 for bash, 1 for perl 
    # after getting version, we only take the first one because for cloud recovery we create a script with version string in it , whihc duplicate string
    VER=`(grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i ) | head -1`
    #echo "VER=$VER"
    if [ -z "$VER" ]; then
      #echo "KO: predownload             $i : undefined version"
      VER1="undefinedversion"
    else
      #echo "OK: predownload             $i $VER"
      VER1=$VER
    fi
  else
    #echo "WARNING : script $localinstalldir/$i missing before download\n" 
    VER1="missinglocal"
  fi
  aws s3 cp $remoteinstalldir/$i  $localinstalldir --quiet
  if [ -e "$localinstalldir/$i" ]; then
    chmod +x $localinstalldir/$i
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`(grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i ) | head -1`
    if [ -z "$VER" ]; then
      #echo "KO: after download $i : undefined version"
      VER2="undefinedversion"
      STATUS="KO"
      ((nbko+=1))
    else
      #echo "OK: after download script $i present. version=$VER"
      VER2=$VER
      STATUS="OK"
      ((nbok+=1))
    fi
  else
    #echo "KO: script $remoteinstalldir/$i is missing in s3, please add it there and relaunch this script\n"  
    VER2="missingfromremote"
    STATUS="KO"
    ((nbko+=1))
  fi
  echo "STATUS=$STATUS file=$i $VER1->$VER2"
done
if [ -e "$localinstalldir/splunkconf-cloud-recovery.sh" ]; then
  if [ -e "$localinstalldir/splunkconf-aws-recovery.sh" ]; then
    echo "WARNING : old AWS cloud recovery exist, overwriting aws version in case old one still present in install bucket"
    echo "WARNING : please remove all splunkconf-aws-recovery.sh from S3 , local and also check user-data if you dont want to see this message again"
    cp -p "$localinstalldir/splunkconf-cloud-recovery.sh" "$localinstalldir/splunkconf-aws-recovery.sh"
  fi
fi


# scripts that run as splunk and deployed in the scripts dir
localinstalldir="/opt/splunk/scripts"
mkdir -p $localinstalldir
for i in splunkconf-prepare-es-from-s3.sh
do
  ((total+=1))
  if [ -e "$localinstalldir/$i" ]; then
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`(grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i ) | head -1`
    if [ -z "$VER" ]; then
      #echo "KO: predownload             $i : undefined version"
      VER1="undefinedversion"
    else
      #echo "OK: predownload             $i version=$VER"
      VER1=$VER
    fi
  else
    #echo "WARNING : script $localinstalldir/$i missing before download\n"  
    VER1="missinglocal"
  fi
  aws s3 cp $remoteinstalldir/$i  $localinstalldir --quiet
  if [ -e "$localinstalldir/$i" ]; then
    # chown specific here
    chown splunk. $localinstalldir/$i
    chmod +x $localinstalldir/$i
    # 2 versions of grep, 1 for bash, 1 for perl
    VER=`(grep ^VERSION $localinstalldir/$i || grep ^\\$VERSION $localinstalldir/$i ) | head -1`
    if [ -z "$VER" ]; then
      #echo "KO: after download : $i undefined version"
      VER2="undefinedversion"
      STATUS="KO"
      ((nbko+=1))
    else
      #echo "OK: after download script $i present. version=$VER"
      VER2=$VER
      STATUS="OK"
      ((nbok+=1))
    fi
  else
    #echo "KO: script $remoteinstalldir/$i is missing in s3, please add it there and relaunch this script\n"
    VER2="missingfromremote"
    STATUS="KO"
    ((nbko+=1))
  fi
  echo "STATUS=$STATUS file=$i $VER1->$VER2"

done

# set back to original dir
localinstalldir="/usr/local/bin"

if [ -z "$splunktargetbinary" ]; then
  splunktargetbinary=`grep ^splbinary $localinstalldir/splunkconf-cloud-recovery.sh | cut -d"\"" -f2`
  echo "INFO: splunktargetbinary not SET in instance tags, version used will be the one hardcoded in script : $splunktargetbinary"
  echo "INFO: This is fine if you are just testing or always want to use script version"
elif [ "$splunktargetbinary" == "auto" ]; then
  splunktargetbinary=`grep ^splbinary $localinstalldir/splunkconf-cloud-recovery.sh | cut -d"\"" -f2`
  echo "INFO: splunktargetbinary=auto via instance tags, version used will be the one hardcoded in script : $splunktargetbinary"
else
  echo "INFO: splunksplunktargetbinary=$splunktargetbinary."
fi
echo "INFO: checking RPM is present in s3 install at $remoteinstalldir/$splunktargetbinary"
#aws s3 cp $remoteinstalldir/$splunktargetbinary /tmp --quiet
if [ "$(aws s3 ls $remoteinstalldir/$splunktargetbinary | grep -ic $splunktargetbinary)" -eq 1 ]; then
#if [ -e "/tmp/$splunktargetbinary" ]; then
  echo "OK: Splunk binary installation file (RPM or tar.gz)  $splunktargetbinary is present in s3 install at location $remoteinstalldir/$splunktargetbinary"
else
  if (( splunkconnectedmode == 1 )); then
    echo "WARNING: Splunk binary installation file (RPM or tar.gz)  $splunktargetbinary is NOT present in s3 install ($remoteinstalldir/$splunktargetbinary) : Please upload file to $remoteinstalldir or check tag value (we will try to download $splunktargetbinary automatically) (also check enough space to download)"
  else
    echo "KO: Splunk binary installation file (RPM or tar.gz)  $splunktargetbinary is NOT present in s3 install ($remoteinstalldir/$splunktargetbinary) : Please upload file to $remoteinstalldir or check tag value (you are running in disconnected mode)"
  fi
fi

# no longer needed
#echo "INFO: launch me a second time if this script version changed, that will make sure you run with the latest one"

echo "INFO: Update Summary ok=$nbok,ko=$nbko,total=$total"

echo "INFO: removing secondary script as no longer needed"
echo "INFO: end of splunkconf upgrade precheck script (updated version=$VERSION, no need to rerun it)"
echo "INFO: please run splunkconf-upgrade-local.sh when ready and if no errors above"
echo "INFO: make sure you have completed all other upgrade requirements before (see doc) and that you upgrade in the right order"
echo "disk space check : "
df --local --total
rm $localinstalldir/splunkconf-upgrade-local-precheck-2.sh

