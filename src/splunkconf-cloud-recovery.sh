#!/bin/bash -x 
exec >> /var/log/splunkconf-cloud-recovery-debug.log 2>&1

# Copyright 2021 Splunk Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributor :
#
# Matthieu Araman, Splunk
#
# This script is used either :
#   - after cloud user-data launched by AWS S3 autoscaling to setup the OS , dowwnload and restore files to prepare for Splunk isntallation upgrade
#   - on a running instance to perform a upgrade (same thing but the OS partition are expected to be there and the reboot is not done as we havent updated the system)

# this script is expecting that :
# instances tags were configured and already written to /etc/instance-tags by user-data
# 
# this script is :
# - creating the splunk user (unless existing)
# - setting up the os partitions for splunk
# - downloading and setting up tuning for Splunk (ulimits, THP, TCP/IP and kernel + systemd / policykit integration for running splunk in systemd mode) 
# - downloading and restoring conf backups (for kvdump, copying the file that will be autonatically restored inside splunk by splunkconf-backup)
# - downloading and install splunk via rpm
# - setting up Splunk service (accept license, enable boot start, upgrade if necessary)
# - rebooting at the end as this is needed if we are in install mode and just updated the system

# 20180626 init and merge back things from Ivan version
# 20181127 add debug log
# 20190314 fixes and more things
# 20190326 change modinput to state to match newer splunkconf backup scripts naming convention
# 20190326 add call to script /opt/splunk/scripts/aws_dns_update/dns_update.sh if it exist (downloaded as part of the backup) which can be useful for updating for example cluster master entry in aws dns
# 20190912 update and more var
# 20190913 generalize post install hook to have it directly from s3
# 20190914 update disk init for newer linu
# 20190915 update script name, comments, glue for init, improve fixed hostname for first time installx
# 20190918 move all splunk init to splunkconf-init
# 20190925 fix permission order for indexes dir 
# 20190927 uniformize -> to var/backups not var/backup, helper script changed to root script dir, more comments, update splunk version to 7.3.1.1
# 20190928 legerage new user data that create /etc/ec2-tags containing s3 bucket names and instance type
# 20190929 add explicit polkit deployment for aws2 ami case
# 20191001 move partition for indx after ec2 tags + cleanuo 
# 20191001 add tuned installation for aws2 case (to be more rh like)
# 20200203 change order to better work by default when upgrading at same time (minor version for example) (better to use backup then upgrade so that will update a file if in conflict between backup and product as it is owned by product) (that avoid having to list all the product files and maintain the exclusion list) + prefer to use the kvdump as there are more chance that this is valid (and take less space !) 
# 20200413 add curl package installation just in case (should be present in most os installation), move logs to usual system dir, add protection mechanism to avoid breaking big kvdump restore that would start in //
# 20200414 fix typo and add extra dir creation for user seed copy 
# 20200416 add support for post launch mode to be able to deploy partially splunk on ephemeral
# 20200503 add exclusion to avoid overriding this script with older version from backup, add extra test and copy for sessions.py (8.0 specific)
# 20200512 disable backup restore test for idx case
# 20200617 add description and improve logs, add var for VERSION, add ugrade mode (that is not requiring destroying the instance and recreating), integrate getting tags so that it run in upgrade mode also
# 20200618 change disk creation code for imdsv2 + ephemeral or EBS (1 type)
# 20200618 readd indexes dir creation and permissions
# 20200623 add lvm package installation when missing in image , add exclusion for case where script is deployed in /usr/local/bin
# 20200623 add support for tags with splunk prefix (with legacy mode if the filter is removed) and filter on prefix for instance tags file creation, move splunk home to ephemeral for i3+smarstore scenario
# 20200624 add detection logic for tags with or without prefix tag to ease migration scenarios, disable bash e flag 
# 20200624 integrate and generalize AZ detection logic to build site app for indexers
# 20200625 add initialtlsapps to package dir to ease initial tls deployment 
# 20200626 add aws-terminate systemd service helper to optimize indexer scale down events
# 20200629 prioritize custom certs from s3 over ones in backup to ease upgrade scenarios
# 20200720 add support for one disk instance (not recommended for vol management but can be useful for lab)
# 20200911 change default version to 8.0.6
# 20200925 add deployment of upgrade-local script for install mode only
# 20200927 add logic to detect RH6 versus RH7+ and apply different tuning system dymamically (by having both packages on S3 with fallback mechanism to not break previous package name   
# 20200927 fix splunk prefix tag detection, add splunktargetbinary tag usage
# 20200929 add tuned service start for AWS2 case
# 20201006 deploy splunkconfbackup from s3 (needed for upgrade case) and remove old cron version if present to prevent double run + update autonatically master_uri to splunk-cm.awsdnszone 
# 20201007 various fixes + add --no-prompt when calling splunkconf-init
# 20201009 optimize restore detection logging 
# 20201010 add splunksecrets deployment via pip, add more cases and safeguards for splunkconf-backup deployment in a existing env
# 20201011 extend master_uri to use tag + also ds + targetsplunkenv + optionnally run a specific env script (used for disabling stuff (mails, external ticketing,...) in a test env for example )
# 20201011 rename error log file to debug
# 20201011 add gdb package for making sure pstack is there (in case support ask for it)
# 20201011 add check for root user (only useful when manually launched)
# 20201012 remove accidental whitespaces from tags at fetch time (for example prevent fail upgrade because the rpm check would fail) (copy/paste...)
# 20201015 add special case for giving dir to splunk for indexer creation case (when fs created in AMI)
# 20201017 add master_uri (cm) support for idx discovery + lm support 
# 20201022 add support for using extra splunkconf-swapme.pl to tune swap
# 20201102 set permission for local upgrade script, add copy for extra check and set tags, update to 8.0.7 by default
# 20201103 add download ES from s3 pre install script
# 20201106 remove any extra spaces in tags around the = sign
# 20201106 make master_uri form more restrictive in server.conf
# 20201109 yet another fix for master_uri regex
# 20201110 remove sessions.py test , move es prep script outside test to have it downloaded in all cases
# 20201110 fix typo in splunktargetenv support 
# 20201111 add java openjdk 1.8 installation (needed for dbconnect for example)
# 20210120 disable default master_uri replacement without tags
# 20210125 change aws to cloud + initial gcp detection
# 20210125 add GPG key check for RPM + direct download option in case RPM not in install bucket
# 20210125 move aws s3 cp to a function and add GCP support
# 20210125 change logging to not clean file at launch + add first boot check (needed for GCP which launch the script at every boot)
# 20210126 add support for setting hostname at boot for gcp, add tests and more meaningfull messages when missing backups or initial files 
# 20210127 add zone detection support for GCP
# 20210127 add dns update support for GCP dns zones (need a splunkdnszoneid tag)
# 20210128 extend ephemeral support to GCP local ssd
# 20210131 inline splunk aws terminate to ease packaging
# 20210131 fix yum option that allow installing on missing rpm (to allow // install in general but still work when the rpm doesnt exist on sone os)
# 20210131 add test to only deploy terminate on systemd os 
# 20210202 splunk 8.1.2
# 20210216 add group + restore permissions on /usr/local/bin for indexer systemd terminate service 
# 20210409 splunk 8.1.3
# 20210526 splunk 8.1.4 as default + add 8.2.0 (not yet default)
# 20210526 add tar mode splbinary detection with logic to setup multiple instances in ds mode via splunkconf-init
# 20210527 add ds lb script deployment
# 20210531 move os detection + change system hostname to functions called at beginning then include route53 update for aws case to be inlined at beginning to avoid having to push extra script and speed up update (+remove some commented line fromn get_object conversion)
# 20210531 more get_object comment clean up and fixes for route53 inline
# 20210608 add splunkorg option to splunkconf-init call
# 20210614 add splunk-appinspect installation for multids
# 20210627 add check and stop when not yum as not currently fully implemented otherwise
# 20210627 add splunkconnectedmode tag + initial detection logic
# 20210627 add splunkosupdatemode tag
# 20210627 add rpm for 8.2.1 (no change to default)
# 20210707 fix regression in splunkconf-backup du to splunkbase packaging change
# 20210707 add splunkcloudmode support to ease deploying collection layer to splunkcloud or test instance that index to splunkcloud
# 20210719 up default to 8.1.5 
# 20210902 add splunkinstancesnb tag support (multids only)
# 20210906 up default to 8.2.2
# 20210907 add splunkcloudmode for gcp case
# 20211017 add more tag support to be able to use various splunkconf-init options from recovery, add initial support for custom user/group in the recovery part
# 20211021 more tag support
# 20211120 fix typo and add more error checking for multids script presence
# 20220102 fix cloud detection for newer AWS kernels
# 20220112 fix tag renaming support when splunkdnszone used (and add DEPRECATED warning to the old splunkawsdnszone )
# 20220112 increase token validity for aws metadata 
# 20220121 disable ami hotpatch not needed for splunk
# 20220129 deploy splunkconf-ds-reload.sh for ds instances type

VERSION="20220129a"

# dont break script on error as we rely on tests for this
set +e

TODAY=`date '+%Y%m%d-%H%M_%u'`;
echo "${TODAY} running splunkconf-cloud-recovery.sh with ${VERSION} version" >> /var/log/splunkconf-cloud-recovery-info.log

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

# we will use SYSVER to store version type (used for packagesystem and hostname setting for example)
function check_sysver() {
  SYSVER=6
  if ! command -v hostnamectl &> /dev/null
  then
    echo "hostnamectl command could not be found -> Assuming RH6/AWS1 like distribution" >> /var/log/splunkconf-cloud-recovery-info.log
    SYSVER=6
  else
    echo "hostnamectl command detected, assuming RH7+ like distribution" >> /var/log/splunkconf-cloud-recovery-info.log
    # note we treat RH8 like RH7 for the moment as systemd stuff that works for RH7 also work for RH8 
    SYSVER=7
  fi
}

function set_hostname() {
  # set the hostname except if this is auto or contain idx or generic name
  if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
    echo "specific instance name : changing hostname to ${instancename} at system level"
    if [ $SYSVER -eq "6" ]; then
      echo "Using legacy method" >> /var/log/splunkconf-cloud-recovery-info.log
      # legacy ami type , rh6 like
      sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${instancename}/g" /etc/sysconfig/network
      # dynamic change on top in case correct hostname is needed further down in this script 
      hostname ${instancename}
      # we should call a command here to force hostname immediately as splunk commands are started after
    else     
      # new ami , rh7+,...
      echo "Using new hostnamectl method" >> /var/log/splunkconf-cloud-recovery-info.log
      hostnamectl set-hostname ${instancename}
    fi
  else
    echo "indexer -> not changing hostname"
  fi
}

get_object () {
  if [ $# == 2 ]; then
    # correct
    orig=$1
    dest=$2
    if [ $cloud_type == 2 ]; then 
      echo "using GCP version with orig=$orig and dest=$dest\n"
      gsutil -q cp $orig $dest
    else
      aws s3 cp $orig $dest --quiet
    fi
  else
    echo "number of arguments passed to get_object is incorrect ($# instead of 2)\n"
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
     splunkconnectedmode=0
  fi
 # if 
 # elif 

 # fi

}

check_cloud
check_sysver

echo "cloud_type=$cloud_type, sysver=$SYSVER"

if [ $cloud_type == 2 ]; then
  # GCP
  if [ $# -eq 0 ]; then
    # not in upgrade mode
    if [ -e "/root/first_boot.check" ]; then 
      . /etc/instance-tags
      instancename=$splunkinstanceType 
      echo "splunkinstanceType : instancename=${instancename}" >> /var/log/splunkconf-cloud-recovery-info.log
      if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
        echo "Setting hostname to ${instancename} via hostnamectl method" >> /var/log/splunkconf-cloud-recovery-info.log
        hostnamectl set-hostname ${instancename}
      fi
      echo "First boot already ran, exiting to prevent loop"
      exit 0
    fi
  touch "/root/first_boot.check"
  fi
fi


# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "Exiting ! This recovery script need to be run as root !" 
   exit 1
fi

if [ $# -eq 1 ]; then
  MODE=$1
  echo "Your command line contains 1 argument $MODE" >> /var/log/splunkconf-cloud-recovery-info.log
  if [ "$MODE" == "upgrade" ]; then 
    echo "upgrade mode" >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "unknown parameter, ignoring" >> /var/log/splunkconf-cloud-recovery-info.log
    MODE="0"
  fi
elif [ $# -gt 1 ]; then
  echo "Your command line contains too many ($#) arguments. Ignoring the extra data" >> /var/log/splunkconf-cloud-recovery-info.log
  MODE=$1
  if [ "$MODE" == "upgrade" ]; then 
    echo "upgrade mode" >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "unknown parameter, ignoring" >> /var/log/splunkconf-cloud-recovery-info.log
    MODE="0"
  fi
else
  echo "No arguments given, assuming launched by user data" >> /var/log/splunkconf-cloud-recovery-info.log
  MODE="0"
fi

echo "running with MODE=${MODE}" >> /var/log/splunkconf-cloud-recovery-info.log

# setting variables

SPLUNK_HOME="/opt/splunk"
INSTANCEFILE="/etc/instance-tags"

if [[ "cloud_type" -eq 1 ]]; then
  # aws
  # we get most var dynamically from ec2 tags associated to instance

  # getting tokens and writting to /etc/instance-tags

  # setting up token (IMDSv2)
  TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
  # lets get the s3splunkinstall from instance tags
  INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
  REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `

  # we put store tags in /etc/instance-tags -> we will use this later on
  aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/'  | grep -E "^splunk" > $INSTANCEFILE
  if grep -qi splunkinstanceType $INSTANCEFILE
  then
    # note : filtering by splunk prefix allow to avoid import extra customers tags that could impact scripts
    echo "filtering tags with splunk prefix for instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "splunk prefixed tags not found, reverting to full tag inclusion" >> /var/log/splunkconf-cloud-recovery-info.log
    aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/'  > $INSTANCEFILE
  fi
elif [[ "cloud_type" -eq 2 ]]; then
  # GCP
  splunkinstanceType=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkinstanceType`
  if [ -z ${splunkinstanceType+x} ]; then
    echo "GCP : Missing splunkinstanceType in instance metadata"
  else 
    # > to overwrite any old file here (upgrade case)
    echo -e "splunkinstanceType=${splunkinstanceType}\n" > $INSTANCEFILE
  fi
  splunks3installbucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3installbucket`
  if [ -z ${splunks3installbucket+x} ]; then
    echo "GCP : Missing splunks3installbucket in instance metadata"
  else 
    echo -e "splunks3installbucket=${splunks3installbucket}\n" >> $INSTANCEFILE
  fi
  splunks3backupbucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3backupbucket`
  if [ -z ${splunks3backupbucket+x} ]; then
    echo "GCP : Missing splunks3backupbucket in instance metadata"
  else 
    echo -e "splunks3backupbucket=${splunks3backupbucket}\n" >> $INSTANCEFILE
  fi
  splunks3databucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3databucket`
  if [ -z ${splunks3databucket+x} ]; then
    echo "GCP : Missing splunks3databucket in instance metadata"
  else 
    echo -e "splunks3databucket=${splunks3databucket}\n" >> $INSTANCEFILE
  fi
  splunkorg=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkorg`
  splunkdnszone=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszone`
  splunkdnszoneid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszoneid`
  numericprojectid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/numeric-project-id`
  projectid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/project-id`
  splunkawsdnszone=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkawsdnszone`
  splunkcloudmode=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkcloudmode`
  splunkconnectedmode=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkconnectedmode`
  splunkosupdatemode=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkosupdatemode`
  splunkdsnb=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdsnb`
  splunksystemd=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemd`
  splunksystemdservicefile=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemdservicefile`
  splunksystemdpolkit=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemdpolkit`
  splunkdisablewlm=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdisablewlm`
  splunkuser=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkuser`
  splunkgroup=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkgroup`
  #=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/`
  
fi

# additional options to splunkconf-init
# default to empty
# if we receive a tag with a non default value, we add it incremetaly to this variable 
# this allow not to call splunkinit will all the options set 
SPLUNKINITOPTIONS=""

if [ -z ${splunksystemd+x} ]; then 
  echo "splunksystemd is unset, falling back to default value of auto"
  splunksystemd="auto"
elif [ ${splunksystemd} -eq "systemd" ]; then 
  SPLUNKINITOPTIONS+=" --systemd=systemd"
elif [ ${splunksystemd} -eq "init" ]; then
  SPLUNKINITOPTIONS+=" --systemd=init"
elif [ ${splunksystemd} -eq "auto" ]; then
  echo "systemd tag set to auto -> default"
else
  echo "unsupported/unknown value for splunksystemd:${splunksystemd} , falling back to default"
fi

# set the mode based on tag and test logic
set_connectedmode


if [ -e "$INSTANCEFILE" ]; then
  chmod 644 $INSTANCEFILE
  # including the tags for use in this script
  . $INSTANCEFILE
else
  echo "WARNING : no instance tags file at $INSTANCEFILE"
fi

# instance type
if [ -z ${splunkinstanceType+x} ]; then 
  if [ -z ${instanceType+x} ]; then
    echo "ERROR : instance tags are not correctly set (splunkinstanceType). I dont know what kind of instance I am ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunkinstanceType)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunkinstanceType=$instanceType
  fi
else 
  echo "using splunkinstanceType from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
# will become the name when not a indexer, see below
instancename=$splunkinstanceType 
echo "splunkinstanceType : instancename=${instancename}" >> /var/log/splunkconf-cloud-recovery-info.log

echo "SPLUNK_HOME is ${SPLUNK_HOME}" >> /var/log/splunkconf-cloud-recovery-info.log

set_hostname

# splunk s3 install bucket
if [ -z ${splunks3installbucket+x} ]; then 
  if [ -z ${s3installbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3installbucket). I dont know where to get the installation files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3installbucket)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunks3installbucket=$s3installbucket
  fi
else 
  echo "using splunks3installbucket from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunks3installbucket is ${splunks3installbucket}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunk s3 backup bucket
if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3backupbucket). I dont know where to get the backup files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3backupbucket)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunks3backupbucket=$s3backupbucket
  fi
else 
  echo "using splunks3backupbucket from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunks3backupbucket is ${splunks3backupbucket}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunk org prefix for base apps
if [ -z ${splunkorg+x} ]; then 
    echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
    #we can continue as we will just do nothing, ok for legacy mode  
    #exit 1
else 
  echo "using splunkorg from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunkorg is ${splunkorg}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunkawsdnszone used for updating route53 when apropriate
if [ -z ${splunkdnszone+x} ]; then 
  if [ -z ${splunkawsdnszone+x} ]; then 
    echo "instance tags are not correctly set (splunkdnszone or splunkawsdnszone). I dont know splunkdnszone to use for updating dns ! Please add splunkdnszone tag" >> /var/log/splunkconf-cloud-recovery-info.log
    #we can continue as we will just do nothing but obviously route53 update will fail if this is needed for this instance
    #exit 1
  else 
    echo "using splunkawsdnszone from instance tags (DEPRECATED, please consider renaming splunkawsdnszone to splunkdnszone) " >> /var/log/splunkconf-cloud-recovery-info.log
    splunkdnszone=$splunkawsdnszone
  fi
fi
if [ -z ${splunkdnszone+x} ]; then 
  echo "splunkdnszone not set, disabling dns update" >> /var/log/splunkconf-cloud-recovery-info.log
else
  echo "using splunkdnszone $splunkdnszone from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
  if [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    echo " indexer , no dns update on this kind of host"
  elif [ $cloud_type == 1 ]; then
    echo "updating dns via route53 api"
    # AWS doing direct dns update in recovery
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
    IP=$( curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 )
    # need iam ->  policy  permissions of
    #
    #{
    #    "Version": "2012-10-17",
    #    "Statement": [
    #        {
    #            "Sid": "VisualEditor0",
    #            "Effect": "Allow",
    #            "Action": [
    #                "route53:ChangeResourceRecordSets",
    #                "route53:ListHostedZonesByName"
    #            ],
    #            "Resource": "*"
    #        }
    #    ]
    #}

    NAME=`hostname --short`
    DOMAIN=$splunkdnszone
    FULLNAME=$NAME"."$DOMAIN

    HOSTED_ZONE_ID=$( aws route53 list-hosted-zones-by-name | grep -i ${DOMAIN} -B5 | grep hostedzone | sed 's/.*hostedzone\/\([A-Za-z0-9]*\)\".*/\1/')
    echo "Hosted zone being modified: $HOSTED_ZONE_ID"

    INPUT_JSON=$(cat <<EOF
{ "ChangeBatch":
 {
  "Comment": "Update the record set of ${FULLNAME}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FULLNAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${IP}"
          }
        ]
      }
    }
  ]
 }
}
EOF
)

    echo "updating dns via route53 API for ${FULLNAME} to ${IP}"
    aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "$INPUT_JSON" || echo "ERROR updating dns record for ${FULLNAME}"
  elif [ -z ${splunkdnszoneid+x} ]; then
    echo "ERROR ATTENTION splunkdnszoneid is not defined, please add it as we cant update dns in GCP without this"
  elif [ $cloud_type == 2 ]; then
    # GCP doing direct dns update in recovery
    MYIP=`ifconfig |  grep -v 127.0.0.1 | grep inet | grep -v inet6 | grep -Eo 'inet\s[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+'`
    OLDIP=`gcloud dns --project=${projectid} record-sets list --zone=${splunkdnszoneid} --name=${instancename}.${splunkdnszone} --type A | tail -1 |grep -Eo '[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+'`
    # the api ask to remove the record with current value before being able to add again ... pretty complex 
    if [ -z "${OLDIP}" ]; then
      echo "MYIP=$MYIP OLDIP=N/A"
      RES=`gcloud dns --project=${projectid} record-sets transaction start --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction add ${MYIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction execute --zone=${splunkdnszoneid}`
    else
      echo "MYIP=$MYIP OLDIP=$OLDIP"
      RES=`gcloud dns --project=${projectid} record-sets transaction start --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction remove ${OLDIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction add ${MYIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction execute --zone=${splunkdnszoneid}`
    fi
  else
    echo "unknown cloud type, not doing any dns update"
  fi 
fi
echo "splunkdnszone is ${splunkdnszone}" >> /var/log/splunkconf-cloud-recovery-info.log
echo "splunkdnszoneid is ${splunkdnszoneid}" >> /var/log/splunkconf-cloud-recovery-info.log
echo "splunkdnszone is ${splunkdnszone}" >> /var/log/splunkconf-cloud-recovery-info.log




localbackupdir="${SPLUNK_HOME}/var/backups"
localinstalldir="${SPLUNK_HOME}/var/install"
SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"
localkvdumpbackupdir="${SPLUNK_DB}/kvstorebackup/"
if [ $cloud_type == 2 ]; then
  remotebackupdir="${splunks3backupbucket}/splunkconf-backup/${instancename}"
  remoteinstalldir="${splunks3installbucket}/install"
  remotepackagedir="${splunks3installbucket}/packaged/${instancename}"
else
  remotebackupdir="s3://${splunks3backupbucket}/splunkconf-backup/${instancename}"
  remoteinstalldir="s3://${splunks3installbucket}/install"
  remotepackagedir="s3://${splunks3installbucket}/packaged/${instancename}"
fi
remoteinstallsplunkconfbackup="${remoteinstalldir}/apps/splunkconf-backup.tar.gz"
# this path expected by ES install script
localappsinstalldir="${SPLUNK_HOME}/splunkapps"
localscriptdir="${SPLUNK_HOME}/scripts"
localrootscriptdir="/usr/local/bin"
# by default try to restore backups
# we will disable if indexer detected as not needed
RESTORECONFBACKUP=1

# splunkuser checks


if [ -z ${splunkuser+x} ]; then 
  usersplunk="splunk"
  splunkuser="splunk"
  echo "splunkuser is unset, default to splunk"
else 
  echo "splunkuser='${splunkuser}'" 
  usersplunk=$splunkuser
fi

if [ -z ${splunkgroup+x} ]; then 
  splunkgroup="splunk"
  echo "splunkgroup is unset, default to splunk"
else 
  echo "splunkgroup='${splunkgroup}'" 
fi

USERFOUND=0
if id "${splunkuser}" &>/dev/null; then
  echo 'splunkuser ${splunkuser} found'
  USERFOUND=1 
else
  echo 'splunkuser ${splunkuser} not found'
  USERFOUND=0 
fi

GROUPFOUND=0
if id "${splunkgroup}" &>/dev/null; then
  echo 'splunkgroup ${splunkgroup} found'
  GROUPFOUND=1
else
  echo 'splunkgroup ${splunkgroup} not found'
  GROUPFOUND=0
fi


# check the splunkuser is not a admin, remove this check only if you understand what that mean

sizeuser=${#splunkuser} 
sizegroup=${#splunkgroup} 
# size min (5 will avoid for exemple calling it root)
sizemin=5


if (( sizeuser < sizemin )); then 
  echo "FAIL : splunk user length too short, minimum = $sizemin, please fix and relaunch"
  exit 1
fi 

if (( sizegroup < sizemin )); then 
  echo "FAIL : splunk group length too short, minimum = $sizemin, please fix and relaunch"
  exit 1
fi 

# fixme add group support here

# fixme more checks here

# manually create the splunk user so that it will exist for next step   
useradd --home-dir ${SPLUNK_HOME} --comment "Splunk Server" ${splunkuser} --shell /bin/bash 

# localbackupdir creation
mkdir -p ${localbackupdir}
chown ${usersplunk}. ${localbackupdir}

mkdir -p ${localinstalldir}
chown ${usersplunk}. ${localinstalldir}

# perl needed for swap (regex) and splunkconf-init.pl
# openjdk not needed by recovery itself but for app that use java such as dbconnect , itsi...
# wget used by recovery
# curl to fetch files
# gdb provide pstack which may be needed to collect things for Splunk support

if ! command -v yum &> /dev/null
  then
  echo "FAIL yum command could not be found, not RH like distribution , not fully implemented/tested at the moment, stopping here " >> /var/log/splunkconf-cloud-recovery-info.log
  exit 1
fi

# one yum command so yum can try to download and install in // which will improve recovery time
yum install --setopt=skip_missing_names_on_install=True wget perl java-1.8.0-openjdk nvme-cli lvm2 curl gdb polkit tuned -y 
# disable as scan in permanence and not needed for splunk
systemctl stop log4j-cve-2021-44228-hotpatch
systemctl disable log4j-cve-2021-44228-hotpatch



if [ "$MODE" != "upgrade" ]; then 
  if [ -z ${splunkosupdatemode+x} ]; then
    splunkosupdatemode="updateandreboot" 
  fi
  if [ "${splunkosupdatemode}" = "disabled" ]; then
    echo "os update disabled, not applying them here. Make sure you applied them already in the os image or use for testing"
  else 
    echo "applying latest os updates/security and bugfixes"
    yum update -y
  fi

  # swap partition creation
  # IMPORTAMT : please emake sure we have really swap available so we can resist peak and reduce OOM risk
  # need at least on sh, idx but also good idea on other roles such as cm
  # safe and arbitrary figure 100G (0.1T) but you can adapt it to your spec and workload
  # obviously this is just a part of strategy about ressource management
  # and you should not swap all time
  #mkswap /dev/sdc
  #echo "/dev/sdc       none    swap    sw  0       0" >> /etc/fstab
  #swapon /dev/sdc
  # end of swap creation
  # if idx
  if [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    #****************************FIXME : REPLACE HERE OR CALL THE NEW PARTITION CODE*********************
    echo "indexer -> configuring additional partition(s)" >> /var/log/splunkconf-cloud-recovery-info.log
    RESTORECONFBACKUP=0
    DEVNUM=1


    # let try to find if we have ephemeral storage
    if [[ "cloud_type" -eq 2 ]]; then
      # gcp
      INSTANCELIST=`nvme list | grep "nvme_card" | cut -f 1 -d" "`
    else
      # aws
      INSTANCELIST=`nvme list | grep "Instance Storage" | cut -f 1 -d" "`
    fi
    echo "instance storage=$INSTANCELIST" >> /var/log/splunkconf-cloud-recovery-info.log

    if [ ${#INSTANCELIST} -lt 5 ]; then
      echo "instance storage not detected" >> /var/log/splunkconf-cloud-recovery-info.log
      INSTANCELIST=`nvme list | grep "Amazon Elastic Block Store" | cut -f 1 -d" "`
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-cloud-recovery-info.log
      NBDISK=0
      for e in ${OSDEVICE}; do
        echo "checking EBS volume $e" >> /var/log/splunkconf-cloud-recovery-info.log
        RES=`mount | grep $e `
        if [ -z "${RES}" ]; then
          echo "$e not found in mounted devices" >> /var/log/splunkconf-cloud-recovery-info.log

          pvcreate $e >> /var/log/splunkconf-cloud-recovery-info.log
          # extend or create vg
          echo "adding $e to vgsplunkstorage${DEVNUM} " >> /var/log/splunkconf-cloud-recovery-info.log
          vgextend vgsplunkstorage${DEVNUM} $e || vgcreate vgsplunkstorage${DEVNUM} $e >> /var/log/splunkconf-cloud-recovery-info.log
          LIST="$LIST $e"
          #pvdisplay
          ((NBDISK=NBDISK+1))
        else
          echo "$e is already mounted, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
        fi
      done
      echo "LIST=$LIST NBDISK=$NBDISK" >> /var/log/splunkconf-cloud-recovery-info.log
      if [ $NBDISK -gt 0 ]; then
        echo "we have $NBDISK disk(s) to configure" >> /var/log/splunkconf-cloud-recovery-info.log
        lvcreate --name lvsplunkstorage${DEVNUM} -l100%FREE vgsplunkstorage${DEVNUM} >> /var/log/splunkconf-cloud-recovery-info.log
        pvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        vgdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        lvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        # note mkfs wont format if the FS is already mounted -> no need to check here
        mkfs.ext4 -L storage1 /dev/vgsplunkstorage1/lvsplunkstorage1 >> /var/log/splunkconf-cloud-recovery-info.log
        mkdir -p /data/vol1
        RES=`grep /data/vol1 /etc/fstab`
        #echo " debug F=$RES."
        if [ -z "${RES}" ]; then
          #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 /data/vol1 && mkdir -p /data/vol1/indexes
          echo "/data/vol1 not found in /etc/fstab, adding it" >> /var/log/splunkconf-cloud-recovery-info.log
          echo "/dev/vgsplunkstorage${DEVNUM}//lvsplunkstorage${DEVNUM} /data/vol1 ext4 defaults,nofail 0 2" >> /etc/fstab
          mount /data/vol1
        else
          echo "/data/vol1 is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
        fi
      else
        echo "no EBS partition to configure" >> /var/log/splunkconf-cloud-recovery-info.log
      fi
      # Note : in case there is just one partition , this will create the dir so that splunk will run
      # for volume management to work in classic mode, it is better to use a distinct partition to not mix manage and unmanaged on the same partition
      echo "creating /data/vol1/indexes and giving to splunk user" >> /var/log/splunkconf-cloud-recovery-info.log
      mkdir -p /data/vol1/indexes
      chown -R ${usersplunk}. /data/vol1/indexes
    else
      echo "instance storage detected"
      #OSDEVICE=$(lsblk -o NAME -n | grep -v '[[:digit:]]' | sed "s/^sd/xvd/g")
      #OSDEVICE=$(lsblk -o NAME -n --nodeps | grep nvme)
      #pvdisplay
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-cloud-recovery-info.log
      for e in ${OSDEVICE}; do
        echo "creating physical volume $e" >> /var/log/splunkconf-cloud-recovery-info.log
        pvcreate $e >> /var/log/splunkconf-cloud-recovery-info.log
        # extend or create vg
        echo "adding $e to vgsplunkephemeral${DEVNUM}" >> /var/log/splunkconf-cloud-recovery-info.log
        vgextend vgsplunkephemeral${DEVNUM} $e || vgcreate vgsplunkephemeral${DEVNUM} $e >> /var/log/splunkconf-cloud-recovery-info.log
        LIST="$LIST $e"
        #pvdisplay
      done
      echo "LIST=$LIST" >> /var/log/splunkconf-cloud-recovery-info.log
      #vgcreate vgephemeral1 $LIST
      lvcreate --name lvsplunkephemeral${DEVNUM} -l100%FREE vgsplunkephemeral${DEVNUM} >> /var/log/splunkconf-cloud-recovery-info.log
      pvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      vgdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      lvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      # note mkfs wont format if the FS is already mounted -> no need to check here
      mkfs.ext4 -L ephemeral1 /dev/vgsplunkephemeral1/lvsplunkephemeral1  >> /var/log/splunkconf-cloud-recovery-info.log
      mkdir -p /data/vol1
      RES=`grep /data/vol1 /etc/fstab`
      #echo " debug F=$RES."
      if [ -z "${RES}" ]; then
        #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 /data/vol1 && mkdir -p /data/vol1/indexes
        echo "/data/vol1 not found in /etc/fstab, adding it" >> /var/log/splunkconf-cloud-recovery-info.log
        echo "/dev/vgsplunkephemeral${DEVNUM}/lvsplunkephemeral${DEVNUM} /data/vol1 ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /data/vol1
        echo "creating /data/vol1/indexes and giving to splunk user" >> /var/log/splunkconf-cloud-recovery-info.log
        mkdir -p /data/vol1/indexes
        chown -R ${usersplunk}. /data/vol1/indexes
        echo "moving splunk home to ephemeral devices in data/vol1/splunk (smartstore scenario)" >> /var/log/splunkconf-cloud-recovery-info.log
        (mv /opt/splunk /data/vol1/splunk;ln -s /data/vol1/splunk /opt/splunk;chown -R ${usersplunk}. /opt/splunk) || mkdir -p /data/vol1/splunk
        SPLUNK_HOME="/data/vol1/splunk"
      else
        echo "/data/vol1 is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
      fi
    fi
    PARTITIONFAST="/data/vol1"
    # FS created in AMI, need to give them back to splunk user
    if [ -e "/data/hotwarm" ]; then
       chown -R ${usersplunk}. /data/hotwarm
       PARTITIONFAST="/data/hotwarm"
       # resize when size in AMI not the right one
       resize2fs /dev/xvda1
       resize2fs /dev/xvdb
    fi
    if [ -e "/data/cold" ]; then
       chown -R ${usersplunk}. /data/cold
    fi
  else
    echo "not a idx, no additional partition to configure" >> /var/log/splunkconf-cloud-recovery-info.log
    PARTITIONFAST="/"
  fi # if idx
  # swap management
  swapme="splunkconf-swapme.pl"
  get_object ${remoteinstalldir}/${swapme} ${localrootscriptdir}
  if [ ! -f "${localrootscriptdir}/${swapme}"  ]; then
    echo "WARNING  : ${swapme} is not present in ${remoteinstalldir}/${swapme}, unable to tune swap  -> please verify the version specified is present" >> /var/log/splunkconf-cloud-recovery-info.log
  else
    chmod u+x ${localrootscriptdir}/${swapme}
    # launching script and providing it info about the main partition that should be SSD like and have some room
    `${localrootscriptdir}/${swapme} $PARTITIONFAST`
  fi
fi # if not upgrade



# Splunk installation
# note : if you update here, that could update at reinstanciation, make sure you know what you do !
#splbinary="splunk-8.0.5-a1a6394cc5ae-linux-2.6-x86_64.rpm"
#splbinary="xxxsplunk-8.0.6-152fb4b2bb96-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.0.7-cbe73339abca-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.1.1-08187535c166-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.1.2-545206cc9f70-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.1.3-63079c59e632-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.1.4-17f862b42a7c-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.1.5-9c0c082e4596-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.2.0-e053ef3c985f-linux-2.6-x86_64.rpm"
#splbinary="splunk-8.2.1-ddff1c41e5cf-linux-2.6-x86_64.rpm"
splbinary="splunk-8.2.2-87344edfcdb4-linux-2.6-x86_64.rpm"

if [ -z ${splunktargetbinary+x} ]; then 
  echo "splunktargetbinary not set in instance tags, falling back to use version ${splbinary} from cloud recovery script" >> /var/log/splunkconf-cloud-recovery-info.log
elif [ ${splunktargetbinary} -eq "auto" ]; then
  echo "splunktargetbinary set to auto in instance tags, falling back to use version ${splbinary} from cloud recovery script" >> /var/log/splunkconf-cloud-recovery-info.log
  unset ${splunktargetbinary}
else 
  splbinary=${splunktargetbinary}
  echo "using splunktargetbinary ${splunktargetbinary} from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "remote : ${remoteinstalldir}/${splbinary}" >> /var/log/splunkconf-cloud-recovery-info.log
# aws s3 cp doesnt support unix globing
get_object ${remoteinstalldir}/${splbinary} ${localinstalldir} 
ls ${localinstalldir}
if [ ! -f "${localinstalldir}/${splbinary}"  ]; then
  echo "RPM not present in install, trying to download directly"
  ###### change from version on splunk : add -q , add ${localinstalldir}/ and add quotes around 
  ######`wget -q -O ${localinstalldir}/splunk-8.1.1-08187535c166-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.1&product=splunk&filename=splunk-8.1.1-08187535c166-linux-2.6-x86_64.rpm&wget=true'`
#####  `wget -q -O ${localinstalldir}/splunk-8.1.2-545206cc9f70-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.2&product=splunk&filename=splunk-8.1.2-545206cc9f70-linux-2.6-x86_64.rpm&wget=true'`
#  `wget -O splunk-8.1.3-63079c59e632-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.3&product=splunk&filename=splunk-8.1.3-63079c59e632-linux-2.6-x86_64.rpm&wget=true'`
#   `wget -q -O ${localinstalldir}/splunk-8.1.4-17f862b42a7c-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.4&product=splunk&filename=splunk-8.1.4-17f862b42a7c-linux-2.6-x86_64.rpm&wget=true'`
#`wget -q -O ${localinstalldir}/splunk-8.1.5-9c0c082e4596-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.5&product=splunk&filename=splunk-8.1.5-9c0c082e4596-linux-2.6-x86_64.rpm&wget=true'`
# `wget -q -O ${localinstalldir}/splunk-8.2.0-e053ef3c985f-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.2.0&product=splunk&filename=splunk-8.2.0-e053ef3c985f-linux-2.6-x86_64.rpm&wget=true'`
#`wget -q -O ${localinstalldir}/splunk-8.2.1-ddff1c41e5cf-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.2.1&product=splunk&filename=splunk-8.2.1-ddff1c41e5cf-linux-2.6-x86_64.rpm&wget=true'`
`wget -q -O ${localinstalldir}/splunk-8.2.2-87344edfcdb4-linux-2.6-x86_64.rpm 'https://d7wz6hmoaavd0.cloudfront.net/products/splunk/releases/8.2.2/linux/splunk-8.2.2-87344edfcdb4-linux-2.6-x86_64.rpm'`
  if [ ! -f "${localinstalldir}/${splbinary}"  ]; then
    echo "ERROR FATAL : ${splbinary} is not present in s3 -> please verify the version specified is present in s3 install (or fix the wget with wget -q -O ... if you just copied paste wget))  " >> /var/log/splunkconf-cloud-recovery-info.log
    # better to exit now and have the admin fix the situation
    exit 1
  fi
else
  echo "succesfully downloaded splbinary ${splbinary} from ${remoteinstalldir}/${splbinary}"
fi

echo "importing GPG key"
cat <<EOF >/root/splunk-gpg-key.pub
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBFtbebEBEADjLzD+QXyTqLwT2UW1Dle5MpBj+C5cbaCIpFEhl+KemcnUKHls
TlCxEpzJczZPiYtcp+wtKCaNG/zoEvYCQ0jKk6Wgoa2cLkDeHtNiuBCHrztgeDTe
FpPT+xmtLoJvu1T0JV/iPG7p5FBGYKOKApnd/awRRC47plCGfVA3VVdQP8jhpMZV
T9C86hWbNo/NRjNH69x1xAe/9POc8KmVxZQb+KGG5tulGIWa7jlTMw850HZwFcft
F13DiAVgCj516K8oZBb5bjgu2ZvpCtMRbCmrzx26ilcB7VJRsTaB6G8MqRzVgLuj
11dTG2XMuBw+3UcjAlZ/y6Cut0Gc5FHIKqwMVXf29y9uXddvIqQnkE0AkOj6flm6
OElvmq7v+NVYLRb9XTy0oWTwOtyGTTso2xwZ8itDT4rIWeta0FxtQPt8Kq369ZGy
CbKl1PU9IrKAeST0AkXyfQXqPc0IzHxz3AhOLzvwm/9/0OWs0ONbxdyTCxQjrhe6
1YBoVv2T5K27fTp7rMFEstyU0NFI3J5P/oxg5ts6y2lCMUB7Q71yAOWVZPgucOAH
7iiNmvrytuGT0c8TfJku1cneajW9jmNvKVD/r3qj6YTAL3mqC0yYx3PiLyUVm8OZ
q90hpFHAI7zV1u6zMqV4EkWg5tEknMWcjQnyIfn0Jx8LedDjbTM8Dt9VKQARAQAB
tCFTcGx1bmssIEluYy4gPHJlbGVhc2VAc3BsdW5rLmNvbT6JAk4EEwEIADgWIQRY
wzMQt6NUwSedtmle+gHts81EIAUCW1t5sQIbAwULCQgHAgYVCAkKCwIEFgIDAQIe
AQIXgAAKCRBe+gHts81EIEsUD/9urCsBW40ahPr1gBsu6TlFbVWFN6TK7NpByecr
KzhDlOGJbh7g1u1qRO88ncUb/iPFfBjpJJ0RbskrZQKVVbmnhLeNPw4oqHq4kNmN
Kc8iV9tynw55Ww5Y0cJoeWrx9Ireub3+1GhKzUomIK0TuQtMULmW7Tdwm46iEDgC
qox2hOutlMFjrT9XOFnluCeyi8HL9m6xUlvvsxYxqWIzWUvoWH3AwpGSPMwg/nzH
Vl1Wz9IJOLqjQFBiA1Vmb/UEkP60JAtXWtNKJ7OqTLag29XBSaJO1NiQFZYb8uCU
GSqNOKYUwiO3ZivmVYlXBT7fC2uHpU45g/d2PrRKgVvIOC9xKiG8+jh/WuWlTl4i
vVjAIEnIFwO8Nig7uoR9xi+0ZxzkP00tGO2Cgv0cFf3TYQrSgrD7QDRBN2az4HtF
WvxJuOYjNLl7mp+Lx0Aj9wtb1WkYNBV0NMXThhnZsDU6Uo6ijJa2uBwkT8MljCHX
n7DjVFZYoZ6m2cwUdR5XSwfpSq0lA7LcSbef4CIC1H0mVxVzeB2B6xGxpVIMNGs4
B1RXW1amVeKmv9ZbTAQpGNVMyGJ8oOhksBFL2Ng0Z5kA9aCuwr1OjyrxBdglfGd/
wmEGIX2cLNNvS+Elh4JzFuKsURWbJ8qFl7cQvKQkS+UTwu7e3CCp8VztfRqPvgQi
A+2oI7kCDQRbW3mxARAAtoBTC9nNiY3301QKzTyPvudD3XI03RZTXVsSHVP4yV0x
fobD2aRhMjxwRjrajZnMCEFKB7yYtsbyiRfznLoycFBse6p4y9gguWEIgaW6TTQP
zQTEgi6AKt38nqDN42L/WurNhAKq9R5X/85vr2t6b18Yp2kw62okbuTtVLjuNwzh
tnZE/HziWVbtBy0KfZ0c6QMUHn7j0U67+QJeIzLcQuBn4qnb177TRtnqNZ9aFTXX
mnUA7qTOAvL+wsoyOcuOboj4N45H5s/izPSiXkoUM1ITuuUI3QHi46zw5cEvSLg+
WImwwZCN4tC275abjxW7XbirglV1EOlCWoALIOAh1BwXDA/JJGwbGOp+ueE7askJ
TiAtP9EM1mJSWnbE9uKDUvEMIaavwtt0kWmQOrB4HFY0AsTOnCxWQYCOb0CDImyq
ScblC3tqvoZzbjPBHQFvxClzxfGdmvQwoxr2WRfsspLPuG1FzgmmX29/WaOV747W
TwJP9xw1OtJmAkq/+CH6J12PmXHy9sJRdk6d1PPEuHjJ588U3Kwc7B5uAtgnwQO8
aS4zPM45y6+J1D2SdM0ydwuqQ9z9wwa022EGTa89k5Vfigx+C/VaDMa1Bu/NSkZ8
7S0NpQGbRwDp76gSKvV1T/15hYVg2nOsI1hTVmM8hVZQO3kO4zFjl0rNNjwWor0A
EQEAAYkCNgQYAQgAIBYhBFjDMxC3o1TBJ522aV76Ae2zzUQgBQJbW3mxAhsMAAoJ
EF76Ae2zzUQg26YP/0dj63ldEluB8L7+dFm9stebcmpgxAugmntdlprDkGi6Rhfd
ks7ufF+mny731GZPcJWIYKi797qerG5O1AI4siaK9FRKzw4PLIGvhOoNg2wrSP/+
7qTFf+ZbT7H5VpIqwcnnnRT05pi1KiMIXW82h47daFYVNhQPbV4+USHwFG7r3Lku
XdiS4hrcoe+Y/a9zGVAdU9QwrT8CuNAw8SYNYx1rJECHiMxmMaEw42a5NARoFdbh
swnR6Mwy5sPhzOHjSI/ZPyM/W9TKAoXfmDQSGDrvnU6NAdpIbP1Ab1FtMjuARfRg
8ndqfm/n8MIvAxjzoBBZkdV5HLOndX3fLVNewnvSWQx9OlV4a7+dKXeQ8TueOMq+
XMA4RKsh3gEMJWbVRZwZnxy+3UKGJD3el0+C7m483ptR8Tj8qBq5KELO0vkcq8+a
eHIbzmQSsj9iAdNfGVLYhimzpZy5NCTl2sgmy4g33pd1jMtUzdFZhvelVzMNlkLZ
AmAJX7yZLQwLsXDEpffgp2S/U8vYAZNTdeZqKvmvCCO+fweRRC7NnnPJQ7nVhL7r
VDxHuk8oMqBQIUdE7Z+WDfyagMMhJWbeMNnnhTZdoPmpXEGkjUKwPDYl+GmF50c1
6vjXtbrcP42pu2IQxiqiaTSLei8LRwPck1eE+78sSUxjVuWRuThoYRhGYoXt
=ivRW
-----END PGP PUBLIC KEY BLOCK-----
EOF
echo "importing GPG key (2)"
rpm --import /root/splunk-gpg-key.pub

INSTALLMODE="rpm"
if [[ ${splbinary} == *.tgz ]] # * is used for pattern matching
then
  echo "non rpm installation, disabling rpm install"; 
  INSTALLMODE="tgz"
else
  echo "RPM installation";
  echo "checking GPG key (rpm)"
  rpm -K "${localinstalldir}/${splbinary}" || (echo "ERROR : GPG Check failed, splunk rpm file may be corrupted, please check and relaunch\n";exit 1)
  INSTALLMODE="rpm"
fi


# no need to do this for multids (in tar mode)
# may need to fine tune the condition later here
#if [ "$INSTALLMODE" -eq "rpm" ]; then
# commented for the moment as we still need the dir structure


  # creating dir as we may not have yet deployed RPM
  mkdir -p ${SPLUNK_HOME}/etc/system/local/
  mkdir -p ${SPLUNK_HOME}/etc/apps/
  mkdir -p ${SPLUNK_HOME}/etc/auth/
  chown -R ${usersplunk}. ${SPLUNK_HOME}
#fi

# tuning system
echo "Tuning system"
if [ "$SYSVER" -eq 6 ]; then
  # RH6/AWS1 like (deprecated)
  echo "remote : ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz  ${localinstalldir} 
  if [ -f "${localinstalldir}/package-systemaws1-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for AWS1 like systems" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-systemaws1-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} 
    echo "deploying system tuning for Splunk" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
  fi
  # enable the system tuning 
  sysctl --system;/etc/rc.d/rc.local 
  # deploying splunk secrets
  yum install -y python36-pip
  pip install --upgrade pip
  pip-3.6 install splunksecrets
else
  # RH7/8 AWS2 like
  # issue on aws2 , polkit and tuned not there by default
  # in that case, restart from splunk user would return
  # Failed to restart splunk.service: The name org.freedesktop.PolicyKit1 was not provided by any .service files
  # See system logs and 'systemctl status splunk.service' for details.
  # despite the proper policy kit files deployed !
  # moved up for perf
  #yum install polkit tuned -y
  systemctl enable tuned.service
  systemctl start tuned.service
  echo "remote : ${remoteinstalldir}/package-system7-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/package-system7-for-splunk.tar.gz  ${localinstalldir} 
  if [ -f "${localinstalldir}/package-system7-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for RH7+ like systems" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system7-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} 
    if [ -f "${localinstalldir}/package-system-for-splunk.tar.gz"  ]; then
      echo "deploying system tuning for Splunk" >> /var/log/splunkconf-cloud-recovery-info.log
      # deploy system tuning (after Splunk rpm to be sure directory structure exist and splunk user also)
      tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
    else
      echo "ATTENTION ERROR system tuning is missing and could not be deployed, check it is on install bucket and instance has access"
    fi
  fi
  # enable the tuning done via rc.local and restart polkit so it takes into account new rules
  sysctl --system;sleep 1;chmod u+x /etc/rc.d/rc.local;systemctl start rc-local;systemctl restart polkit
  # deploying splunk secrets
  pip3 install splunksecrets
fi


if [ "$MODE" != "upgrade" ]; then
  # fetching files that we will use to initialize splunk
  # splunk.secret just in case we are on a new install (ie won't be in the backup)
  echo "remote : ${remoteinstalldir}/splunk.secret" >> /var/log/splunkconf-cloud-recovery-info.log
  # FIXME : temp , logic is in splunkconf-init
  get_object ${remoteinstalldir}/splunk.secret ${SPLUNK_HOME}/etc/auth 

  echo "remote : ${remotepackagedir} : copying initial apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object ${remotepackagedir}/initialapps.tar.gz ${localinstalldir} 
  if [ -f "${localinstalldir}/initialapps.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialapps.tar.gz not found, trying without but this may lead to a non functional splunk. This should contain the minimal apps to attach to the rest of infrastructure"
  fi
  echo "remote : ${remotepackagedir} : copying initial TLS apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  # to ease initial deployment, tls app is pushed separately (warning : once the backups run, backup would restore this also of course)
  get_object  ${remotepackagedir}/initialtlsapps.tar.gz ${localinstalldir} 
  if [ -f "${localinstalldir}/initialtlsapps.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialtlsapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialtlsapps.tar.gz not found, trying without but this may lead to a non functional splunk if you enabled custom certificates. This should contain the minimal apps to configure TLS in order to attach to the rest of infrastructure"
  fi
  echo "remote : ${remotepackagedir} : copying splunkcloud uf app to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  get_object  ${remotepackagedir}/splunkclouduf.spl ${localinstalldir} 
  if [ -f "${localinstalldir}/splunkclouduf.spl"  ]; then
    # 1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration, 3 = byol or manual config to splunkcloud
    if [ -z ${splunkcloudmode+x} ]; then 
      echo "splunkcloudmode not set, setting to manual (3)"
      splunkcloudmode="3"
    fi
    if [ "${splunkcloudmode}" -eq "3" ]; then
      echo "splunkcloudmode is manual, not deploying splunkclouduf.spl (that was present, may be you forgot to set splunkcloudmode tag ?)"
    else 
      echo "deploying splunkclouduf.spl (splunkcloudmode=$splunkcloudmode)"
      # FIXME add clone support here ?
      tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/splunkclouduf.spl >> /var/log/splunkconf-cloud-recovery-info.log
    fi
  else
    echo "${remotepackagedir}/splunkclouduf.spl not found, assuming no need to send to splunkcloud or manual config"
  fi
  echo "remote : ${remotepackagedir} : copying certs " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object  ${remotepackagedir}/mycerts.tar.gz ${localinstalldir}
  if [ -f "${localinstalldir}/mycerts.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 
  else
    echo "${remotepackagedir}/mycerts.tar.gz not found, trying without but this may lead to a non functional splunk if you enabled custom certificates. This should contain the custom certs to configure TLS in order to attach to the rest of infrastructure"
  fi

  ## 7.0 no user seed with hashed passwd, first time we have no backup lets put directly passwd 
  #echo "remote : ${remoteinstalldir}/passwd" >> /var/log/splunkconf-cloud-recovery-info.log
  #aws s3 cp ${remoteinstalldir}/passwd ${localinstalldir} --quiet
  ## copying to right place
  #cp ${localinstalldir}/passwd /opt/splunk/etc/
  #chown -R ${usersplunk}. /opt/splunk

  # giving the index directory to splunk if they exist
  chown -R ${usersplunk}. /data/vol1/indexes
  chown -R ${usersplunk}. /data/vol2/indexes

  # deploy including for indexers
  echo "remote : ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz ${localbackupdir}
  # setting up permissions for backup
  chown ${usersplunk}. ${localbackupdir}/*.tar.gz
  chmod 500 ${localbackupdir}/*.tar.gz
  if [ -f "${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz"  ]; then
    # excluding this script to avoid restoring a older version from backup
    tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh --exclude opt/splunk/scripts/splunkconf-cloud-recovery.sh --exclude usr/local/bin/splunkconf-cloud-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz
  else
    echo "${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz not found, trying without. You can use this to package custom scripts to be deployed at installation time" 
  fi
  if [ "$RESTORECONFBACKUP" -eq 1 ]; then
    # getting configuration backups if exist 
    # change here for kvstore 
    echo "remote : ${remotebackupdir}/backupconfsplunk-etc-targeted.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remotebackupdir}/backupconfsplunk-etc-targeted.tar.gz ${localbackupdir}
    # at first splunk install, need to recreate the dir and give it to splunk
    mkdir -p ${localkvdumpbackupdir};chown ${usersplunk}. ${localkvdumpbackupdir}
    echo "remote : ${remotebackupdir}/backupconfsplunk-kvdump.tar.gz " >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remotebackupdir}/backupconfsplunk-kvdump.tar.gz ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz
    # making sure splunk user can access the backup 
    chown ${usersplunk}. ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz
    # and only
    chmod 500 ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz
    echo "remote : ${remotebackupdir}/backupconfsplunk-kvstore.tar.gz " >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remotebackupdir}/backupconfsplunk-kvstore.tar.gz ${localbackupdir}

    echo "remote : ${remotebackupdir}/backupconfsplunk-state.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remotebackupdir}/backupconfsplunk-state.tar.gz ${localbackupdir}

    echo "remote : ${remotebackupdir}/backupconfsplunk-scripts.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remotebackupdir}/backupconfsplunk-scripts.tar.gz ${localbackupdir}

    # setting up permissions for backup
    chown ${usersplunk}. ${localbackupdir}/*.tar.gz
    chmod 500 ${localbackupdir}/*.tar.gz

    echo "localbackupdir ${localbackupdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
    ls -l ${localbackupdir} >> /var/log/splunkconf-cloud-recovery-info.log

    echo "localkvdumpbackupdir ${localkvdumpbackupdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
    ls -l ${localkvdumpbackupdir} >> /var/log/splunkconf-cloud-recovery-info.log

    # untarring backups  
    if [ -f "${localbackupdir}/backupconfsplunk-etc-targeted.tar.gz"  ]; then
      # configuration (will redefine collections as needed)
      tar -C "/" -xf ${localbackupdir}/backupconfsplunk-etc-targeted.tar.gz
    else
      echo "${remotebackupdir}/backupconfsplunk-etc-targeted.tar.gz not found, trying without. This is normal if this is the first time this instance start or for instances without backup such as indexers" 
    fi
    if [ -f "${localinstalldir}/mycerts.tar.gz"  ]; then
      # if we updated certs, we want them to optionally replace the ones in backup
      tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 
    fi
    # restore kvstore ONLY if kvdump not present
    file="${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz"
    if [ -e "$file" ]; then
      echo "kvdump exist ($file), it will be automatically restored by splunkconf-backup app at one of next Splunk launch " >> /var/log/splunkconf-cloud-recovery-info.log
      # when needed kvdump will be restored later as it need to be done online
    else 
      echo "kvdump backup does not exist. This is normal for indexers, for first time instance creation or for pre 7.1 Splunk. Otherwise please investigate " >> /var/log/splunkconf-cloud-recovery-info.log
      file="${localbackupdir}/backupconfsplunk-kvstore.tar.gz"
      if [ -e "$file" ]; then
         echo "kvstore backup exist and is restored" >> /var/log/splunkconf-cloud-recovery-info.log
         tar -C "/" -xf ${localbackupdir}/backupconfsplunk-kvstore.tar.gz
      else
         echo "Neither kvdump or kvstore backup exist, doing nothing. This is normal for indexers and first time instance creation, investigate otherwise" >> /var/log/splunkconf-cloud-recovery-info.log
      fi
    fi 
    if [ -f "${localbackupdir}/backupconfsplunk-state.tar.gz"  ]; then
      tar -C "/" -xf ${localbackupdir}/backupconfsplunk-state.tar.gz
    else 
      echo "${remotebackupdir}/backupconfsplunk-state.tar.gz not found, trying without"
    fi 
    # need to be done after others restore as the cron entry could fire another backup (if using system version)
    if [ -f "${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz"  ]; then
      tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh --exclude opt/splunk/scripts/splunkconf-cloud-recovery.sh --exclude usr/local/bin/splunkconf-cloud-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz
    fi
    if [ -f "${localbackupdir}/backupconfsplunk-scripts.tar.gz"  ]; then
      tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh --exclude opt/splunk/scripts/splunkconf-cloud-recovery.sh --exclude usr/local/bin/splunkconf-cloud-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts.tar.gz
    fi
  # if restore
  fi

  # set the hostname except if this is auto or contain idx or generic name
  # below is the exception criteria (ie indexer, uf  we cant set the name for example as there can be multiple instance of the same type)
  if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
    echo "specific instance name : changing hostname to ${instancename} "
    # first time actions 
    # set instance names if splunk instance was already started (in the ami or from the backup...) 
    sed -i -e 's/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${instancename}/g' ${SPLUNK_HOME}/etc/system/local/inputs.conf
    sed -i -e 's/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${instancename}/g' ${SPLUNK_HOME}/etc/system/local/server.conf
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/inputs.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing inputs.conf with ${instancename}\n"
      echo "[default]" > ${SPLUNK_HOME}/etc/system/local/inputs.conf
      echo "host = ${instancename}" >> ${SPLUNK_HOME}/etc/system/local/inputs.conf
      chown ${usersplunk}. ${SPLUNK_HOME}/etc/system/local/inputs.conf
    fi
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/server.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing server.conf with ${instancename}\n"
      echo "[general]" > ${SPLUNK_HOME}/etc/system/local/server.conf
      echo "serverName = ${instancename}" >> ${SPLUNK_HOME}/etc/system/local/server.conf
      chown ${usersplunk}. ${SPLUNK_HOME}/etc/system/local/server.conf
    fi
  elif [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    if [ -z ${splunkorg+x} ]; then 
      echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
      splunkorg="org"
    else 
      echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
    fi
    if [[ "cloud_type" -eq 2 ]]; then
      # gcp
      AZONE=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/zone`
    else # 1= AWS    
      AZONE=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone  `
    fi
    ZONELETTER=${AZONE: -1}
    sitenum=0
    # depending on region and what the user enabled there could be more than the first 3 AZ (example virginia)
    # the admin could have chosen different AZ
    # the site list should be defined and exactly matching what is used in the CM configuration
    case $ZONELETTER in
      a)
        sitenum="1" ;;
      b)
        sitenum="2" ;;
      c)
        sitenum="3" ;;
      d)
        sitenum="4" ;;
      e)
        sitenum="5" ;;
      f)
        sitenum="6" ;;
      g)
        sitenum="7" ;;
      h)
        sitenum="8" ;;
    esac
    site="site${sitenum}"
    echo "Indexer detected setting site for availability zone $AZONE (letter=$ZONELETTER,sitenum=$sitenum, site=$site) " >> /var/log/splunkconf-cloud-recovery-info.log
    # removing any conflicting app that could define site
    # giving back files to splunk user (this is required here as if the permissions are incorrect from tar file du to packaging issues, the delete from splunk below will fail here)
    chown -R ${usersplunk}. $SPLUNK_HOME
    FORME="*site*base"
    # find app that match forn and deleting the app folder
    su - ${usersplunk} -c "/usr/bin/find $SPLUNK_HOME/etc/apps/ -name \"${FORME}\" -exec rm -r {} \; "
    find $SPLUNK_HOME/etc/apps/ -name \"\*site\*base\" -delete -print >> /var/log/splunkconf-cloud-recovery-info.log
    mkdir -p "$SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local"
    echo -e "#This configuration was automatically generated based on indexer location\n#This site should be defined on the CM\n[general] \nsite=$site" > $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local/server.conf
    # giving back files to splunk user
    chown -R ${usersplunk}. $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base
    echo "Setting Indexer on site: $site" >> /var/log/splunkconf-cloud-recovery-info.log
    if [ $SYSVER -eq "6" ]; then
      echo "running non systemd os , we wont add a custom service to terminate"
    else
      echo "running systemd os , adding Splunk idx terminate service"
      # this service is ran at stop when a instance is terminated cleanly (scaledown event)
      # if will run before the normal splunk service and run a script that use the splunk offline procedure 
      # in order to tell the CM to replicate before the instance is completely terminated
      # we dont want to run this each time the service stop for cases such as rolling restart or system reboot
      read -d '' SYSAWSTERMINATE << EOF
[Unit]
Description=Splunk idx terminate helper Service
Before=poweroff.target shutdown.target halt.target
# so that it will stop before splunk systemd unit stop
Wants=splunk.target
Requires=network-online.target network.target sshd.service

[Service]
KillMode=none
ExecStart=/bin/true
#ExecStop=/bin/bash -c "/usr/bin/su - splunk -s /bin/bash -c \'/usr/local/bin/splunkconf-aws-terminate-idx\'";true
ExecStop=/bin/bash /usr/local/bin/splunkconf-aws-terminate-idx.sh
RemainAfterExit=yes
Type=oneshot
# stop after 15 min anyway as a safeguard, the shell script should use a timeout below that value
TimeoutStopSec=15min
User=splunk
Group=splunk

[Install]
WantedBy=multi-user.target

EOF

      echo "$SYSAWSTERMINATE" > /etc/systemd/system/aws-terminate-helper.service
      read -d '' SPLUNKOFFLINE << EOF
#!/bin/bash

# Matthieu Araman, Splunk
# 20200625 initial version
# 20200626 typos fix in log
# 20210131 typos fix and deployment inlined
# 20210216 fix escaping variable when inlined

SPLUNK_HOME="/opt/splunk"
LOGFILE="\${SPLUNK_HOME}/var/log/splunk/splunkconf-backup.log"

SCRIPTNAME="splunkconf-aws-terminate-idx"

# value need to be under the timeout in service (600s)
DECOMISSION_NODE_TIMEOUT=530

###### function definition

function echo_log_ext {
    LANG=C
    #NOW=(date "+%Y/%m/%d %H:%M:%S")
    NOW=(date)
    echo `$NOW`" \${SCRIPTNAME} \$1 " >> \$LOGFILE
}


function echo_log {
    echo_log_ext  "INFO id=\$ID \$1"
}

function warn_log {
    echo_log_ext  "WARN id=\$ID \$1"
}

function fail_log {
    echo_log_ext  "FAIL id=\$ID \$1"
}


# this script should run as splunk
echo_log "checking that we were not launched by root for security reasons"
# check that we are not launched by root
if [[ \$EUID -eq 0 ]]; then
   fail_log "Exiting ! This script must be run as splunk user, not root !"
   exit 1
fi

echo_log "\$SCRIPTNAME launched, this instance is  being shutdown or terminated, so we will call splunk offline command in a few seconds so that the cluster reassign primaries, replicate the remaining buckets hopefully before splunk stop (and searches may have somne time to complete)"
# let some time for splunk to index and replicate before kill
sleep 10

# note with smartstore, numrber of buckets to resync is reduced, decreasing impact and time
# this command rely on proper systemd + policykit configuration to be in place

\${SPLUNK_HOME}/bin/splunk offline --enforce-counts  --decommission_node_force_timeout \${DECOMISSION_NODE_TIMEOUT}

EOF
      echo "$SPLUNKOFFLINE" > /usr/local/bin/splunkconf-aws-terminate-idx.sh
      # restore permissions in case tar broke them (systemd would complain)
      chown root. /usr/local/bin
      chmod 755 /usr/local/bin
      systemctl daemon-reload
      systemctl enable aws-terminate-helper.service
      chown root.${splunkgroup} ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
      chmod 550 ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
    fi   
  else
    echo "other generic instance type( uf,...) , we wont change anything to avoid duplicate entries, using the name provided by aws"
  fi

  ## deploy or update the backup scripts
  #aws s3 cp ${remoteinstalldir}/install/splunkconf-backup-s3.tar.gz ${localbackupdir} --quiet
  #tar -C "/" -xzf ${localbackupdir}/splunkconf-backup-s3.tar.gz 

  # need user seed when 7.1

  # user-seed.config
  echo "remote : ${remoteinstalldir}/user-seed.conf" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/user-seed.conf ${localinstalldir}
  # copying to right place
  # FIXME : more  logic here
  cp ${localinstalldir}/user-seed.conf ${SPLUNK_HOME}/etc/system/local/
  chown -R ${usersplunk}. ${SPLUNK_HOME}

fi # if not upgrade

# updating master_uri (needed when reusing backup from one env to another)
# this is for indexers, search heads, mc ,.... (we will detect if the conf is present)
if [ -z ${splunktargetcm+x} ]; then
  echo "tag splunktargetcm not set, please consider setting it up (for example to splunk-cm) to be used as master_uri for cm (by default the current config will be kept as is"
  #disabled by default to require tags or do nothing 
  #  splunktargetcm="splunk-cm"
else 
  echo "tag splunktargetcm is set to $splunktargetcm and will be used as the short name for master_uri" >> /var/log/splunkconf-cloud-recovery-info.log
fi

if [ -z ${splunkorg+x} ]; then 
  echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkorg="org"
else 
  echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
# splunkdnszone used for updating route53 when apropriate
if [ -z ${splunkdnszone+x} ]; then 
    echo "instance tags is not defining splunkdnszone. Some features will be disabled such as updating master_uri in a cluster env ! Please consider adding splunkdnszone tag" >> /var/log/splunkconf-cloud-recovery-info.log
elif [ -z ${splunktargetcm+x} ]; then
    echo "instance tags is not defining splunktargetcm. Some features will be disabled such as updating master_uri in a cluster env ! Please consider adding splunktargetcm tag" >> /var/log/splunkconf-cloud-recovery-info.log
else 
  echo "using splunkdnszone ${splunkdnszone} from instance tags (master_uri) master_uri=https://${splunktargetcm}.${splunkdnszone}:8089 (cm name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
  # assuming PS base apps are used   (indexer and search)
  # we dont want to update master_uri=clustermaster:indexer1 in cluster_search_base
  find ${SPLUNK_HOME} -wholename "*cluster_search_base/local/server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*https.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
  find ${SPLUNK_HOME} -wholename "*cluster_indexer_base/local/server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
  # it is also used fo rindexer discovery in outputs.conf
  find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/deployment-apps ${SPLUNK_HOME}/etc/shcluster/apps ${SPLUNK_HOME}/etc/system/local  -name "outputs.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
  # $$ echo "master_uri replaced" || echo "master_uri not replaced"
  # this wont work in that form because master_uri could be the one for license find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \;  $$ echo "master_uri replaced" || echo "master_uri not replaced"

  # DS case (targetUri)
  if [ -z ${splunktargetds+x} ]; then
    #echo "tag splunktargetds not set, will use splunk-ds as the short name for targertUri" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "tag splunktargetds not set, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
    #splunktargetds="splunk-ds"
  else
    echo "tag splunktargetds is set to $splunktargetds and will be used as the short name for deploymentclient config to ref the DS" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "using splunkdnszone ${splunkdnszone} from instance tags (targetUri) targetUri=${splunktargetds}.${splunkdnszone}:8089 (ds name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
    find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "deploymentclient.conf" -exec grep -l targetUri {} \; -exec sed -i -e "s%^.*targetUri.*=.*$%targetUri=${splunktargetds}.${splunkdnszone}:8089%" {} \; 
  # $$ echo "targetUri replaced" || echo "targetUri not replaced"
  fi
  # lm case 
  if [ -z ${splunktargetlm+x} ]; then
    echo "tag splunktargetlm not set, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
  else 
    echo "tag splunktargetlm is set to $splunktargetlm and will be used as the short name for master_uri config under [license] in server.conf to ref the LM" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "using splunkdnszone ${splunkdnszone} from instance tags [license] master_uri=${splunktargetlm}.${splunkdnszone}:8089 (lm name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
    ${SPLUNK_HOME}/bin/splunk btool server list license --debug | grep -v m/d | grep master_uri | cut -d" " -f 1 | head -1 |  xargs -I FILE -L 1 sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetlm}.${splunkdnszone}:8089%" FILE
  fi
  # fixme add shc deployer case here
fi

if [ -z ${splunktargetenv+x} ]; then
  echo "splunktargetenv tag not set , please consider adding it if you want to automatically modify login banner for a test env using prod backups" >> /var/log/splunkconf-cloud-recovery-info.log
else 
  echo "trying to replace login_content for splunktargetenv=$splunktargetenv"
  find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "web.conf" -exec grep -l login_content {} \; -exec sed -i -e "s%^.*login_content.*=.*$%This is a <b>$splunktargetenv server</b>.<br>Authorized access only" {} \;  && echo "login_content replaced" || echo "login_content not replaced"
  envhelperscript="splunktargetenv-for${splunktargetenv}.sh"
  echo "remote : ${remoteinstalldir}/${envhelperscript}" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/${envhelperscript}  ${localinstalldir}
  if [ -e "${localinstalldir}/$envhelperscript" ]; then
    chown ${usersplunk}. ${localinstalldir}/$envhelperscript
    chmod u+rx  ${localinstalldir}/$envhelperscript
    # give back files 
    chown -R ${usersplunk}. ${SPLUNK_HOME}
    echo "launching $envhelperscript as splunk, please make sure you implement logic inside if needed to restrict to some instances only"  >> /var/log/splunkconf-cloud-recovery-info.log
    su - ${usersplunk} -c "${localinstalldir}/$envhelperscript"
  else
    echo "$envhelperscript not present in ${remoteinstalldir}/${envhelperscript}, please consider creating it if you need to customize things specifically for this ${splunktargetenv} env" >> /var/log/splunkconf-cloud-recovery-info.log  >> /var/log/splunkconf-cloud-recovery-info.log
  fi
fi

## moved with complete logic to splunkconf-init
#${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk -systemd-managed 0 || ${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk
##${SPLUNK_HOME}/bin/splunk enable boot-start -user splunk --accept-license
## if run first time, because we haven't started splunk yet, this risk writing some files as root so lets give them back to splunk
#chown -R ${usersplunk}. ${SPLUNK_HOME}

## redeploy system tuning as enable boot start may have overwritten files
##tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz

if [ "$INSTALLMODE" = "tgz" ]; then
  echo "disabling rpm install as ds in a box install via tar"
else
  echo "installing/upgrading splunk via RPM using ${splbinary}" >> /var/log/splunkconf-cloud-recovery-info.log
  # install or upgrade
  rpm -Uvh ${localinstalldir}/${splbinary}
fi

# give back files (see RN)
chown -R ${usersplunk}. ${SPLUNK_HOME}

## using updated init script with su - splunk
#echo "remote : ${remoteinstalldir}/splunkenterprise-init.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
#aws s3 cp ${remoteinstalldir}/splunkenterprise-init.tar.gz ${localinstalldir} --quiet
#tar -C "/" -xzf ${localinstalldir}/splunkenterprise-init.tar.gz 

# updating splunkconf-backup app from s3
# important : version on s3 should be up2date as it is prioritary over backups and other content
# only if it is not a indexer 
if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
  get_object ${remoteinstallsplunkconfbackup} ${localinstalldir}
  if [ -e "${localinstalldir}/splunkconf-backup.tar.gz" ]; then
    # backup old version just in case
    tar -C "${SPLUNK_HOME}/etc/apps/" -zcf ${localinstalldir}/splunkconf-backup-${TODAY}.tar.gz ./splunkconf-backup
    # remove so we dont have leftover in local that could break app
    find "${SPLUNK_HOME}/etc/apps/splunkconf-backup" -delete
    # Note : old versions used relative path, new version without du to splunkbase packaging requirement
    tar -C "${SPLUNK_HOME}/etc/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz 
    # removing old version for upgrade case 
    if [ -e "/etc/crond.d/splunkbackup.cron" ]; then
      rm -f /etc/crond.d/splunkbackup.cron
    fi
    mv ${SPLUNK_HOME}/scripts/splunconf-backup ${SPLUNK_HOME}/scripts/splunconf-backup-disabled
    echo "splunkconfbackup found on s3 at ${remoteinstallsplunkconfbackup} and updated from it"
    # we may be on a DS then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a DS"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -zcf ${localinstalldir}/splunkconf-backup-${TODAY}-fromdeploymentapps.tar.gz ./splunkconf-backup
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
    # we may be on a SHC deployer then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a SHC deployer"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -zcf ${localinstalldir}/splunkconf-backup-${TODAY}-fromshclusterapps.tar.gz
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
  else 
    echo "ATTENTION : splunkconf-backup not found on s3 so will not deploy it now. consider adding it at ${remoteinstallsplunkconfbackup} for autonatic deployment"
  fi
fi

if [[ "${instancename}" =~ ds ]]; then
  echo "instance is a deployment server, deploying ds serverclass reload script"
  DSRELOAD="splunkconf-ds-reload.sh"
  mkdir -p ${localscriptdir}
  chown $usersplunk.$groupsplunk ${localscriptdir}/
  chown $usersplunk.$groupsplunk ${localscriptdir}
  chmod 550  ${localscriptdir}
  get_object ${remoteinstalldir}/splunkconf-ds-reload.sh ${localscriptdir}/${DSRELOAD}
  chown $usersplunk.$groupsplunk ${localscriptdir}/${DSRELOAD}
  chmod 550  ${localscriptdir}/${DSRELOAD}
fi


# splunk initialization (first time or upgrade)
mkdir -p ${localrootscriptdir}
get_object ${remoteinstalldir}/splunkconf-init.pl ${localrootscriptdir}/

# make it executable
chmod u+x ${localrootscriptdir}/splunkconf-init.pl 

# we need this set to forward it to splunkconf-init
if [ -z ${splunkorg+x} ]; then
  echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkorg="org"
fi

if [ "$INSTALLMODE" = "tgz" ]; then
  # for app inspect 
  yum groupinstall "Development Tools"
  yum install  python3-devel
  pip3 install splunk-appinspect
  # LB SETUP for multi DS
  get_object ${remoteinstalldir}/splunkconf-ds-lb.sh ${localrootscriptdir}
  if [ ! -e "${localrootscriptdir}/splunkconf-ds-lb.sh" ]; then
    echo " ${localrootscriptdir}/splunkconf-ds-lb.sh doesnt  exist, please fix (add file to expected location) and relaunch"
    exit 1
  fi 
  echo "creating DS LB via LVS"
  chown root. ${localrootscriptdir}/splunkconf-ds-lb.sh 
  chmod 750 ${localrootscriptdir}/splunkconf-ds-lb.sh 
  ${localrootscriptdir}/splunkconf-ds-lb.sh 
  NBINSTANCES=4
  if [ -z ${splunkdsnb+x} ]; then
    echo "multi ds mode used but splunkdsnb tag not defined, using 4 instances (default)"
  else
    NBINSTANCES=${splunkdsnb}
    if (( $NBINSTANCES > 0 )); then 
      echo "set NBINSTANCES=${splunkdsnb}"
   else
      echo " ATTENTION ERROR splunkdsnb is not numeric or contain invalid value, switching back to default 4 instances, please investigate and correct tag (remove extra spaces for example)" 
     NBINSTANCES=4
   fi
  fi
  #NBINSTANCES=1
  echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init for dsinabox with $NBINSTANCES " >> /var/log/splunkconf-cloud-recovery-info.log
  # no need to pass option, it will default to systemd + /opt/splunk + splunk user
  for ((i=1;i<=$NBINSTANCES;i++)); 
  do 
    SERVICENAME="${instancename}_$i"
    echo "setting up instance $i/$NBINSTANCES with SERVICENAME=$SERVICENAME"
    ${localrootscriptdir}/splunkconf-init.pl --no-prompt --splunkorg=$splunkorg --service-name=$SERVICENAME --splunkrole=ds --instancenumber=$i --splunktar=${localinstalldir}/${splbinary} ${SPLUNKINITOPTIONS}
  done
else
  echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init" >> /var/log/splunkconf-cloud-recovery-info.log
  # no need to pass option, it will default to systemd + /opt/splunk + splunk user
  ${localrootscriptdir}/splunkconf-init.pl --no-prompt --splunkorg=$splunkorg ${SPLUNKINITOPTIONS}
fi


echo "localrootscriptdir ${localrootscriptdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
ls ${localrootscriptdir} >> /var/log/splunkconf-cloud-recovery-info.log

echo "localinstalldir ${localinstalldir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
ls ${localinstalldir} >> /var/log/splunkconf-cloud-recovery-info.log

if [ "$MODE" != "upgrade" ]; then 
  # local upgrade script (we dont do this in upgrade mode as overwriting our own script already being run could be problematic)
  echo "remote : ${remoteinstalldir}/splunkconf-upgrade-local.sh" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/splunkconf-upgrade-local.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local.sh  
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local.sh  
  get_object ${remoteinstalldir}/splunkconf-upgrade-local-precheck.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local-precheck.sh  
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local-precheck.sh  
  get_object ${remoteinstalldir}/splunkconf-upgrade-local-setsplunktargetbinary.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local-setsplunktargetbinary.sh
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local-setsplunktargetbinary.sh
  # if there is a dns update to do , we have put the script and it has been redeployed as part of the restore above
  # so we can run it now
  # the content will be different depending on the instance
  #if [ -e /opt/splunk/scripts/aws_dns_update/dns_update.sh ]; then
  #  /opt/splunk/scripts/aws_dns_update/dns_update.sh
  #fi
  # this is restored by backup scripts (initial one) but only present if the admin decided it is necessary (ie for example to update dns for some instances)
  # if needed this is calling other scripts
  if [ -e ${localrootscriptdir}/aws-postinstall.sh ]; then
    echo "lauching aws-postinstall in ${localrootscriptdir}/aws-postinstall.sh" >> /var/log/splunkconf-cloud-recovery-info.log
    chown root. ${localrootscriptdir}/aws-postinstall.sh
    chmod u+x ${localrootscriptdir}/aws-postinstall.sh
    ${localrootscriptdir}/aws-postinstall.sh
    # note if needed , this will transparently call other scripts deployed in the initial backup so that recovery script can stay generic
  fi
fi # if not upgrade

# always download even in upgrade mode

# script run as splunk
# this script is to be used on es sh , it will download ES installation files and script
get_object ${remoteinstalldir}/splunkconf-prepare-es-from-s3.sh  ${localscriptdir}/
if [ -e ${localscriptdir}/splunkconf-prepare-es-from-s3.sh ]; then
  chown splunk. ${localscriptdir}/splunkconf-prepare-es-from-s3.sh
  chmod 700 ${localscriptdir}/splunkconf-prepare-es-from-s3.sh
else
  echo "${remoteinstalldir}/splunkconf-prepare-es-from-s3.sh not existing, please consider add it if willing to deploy ES" 
fi

# apply sessions workaround for 8.0 if needed
# commenting as no longer needed, please comment tools.session timeout in web.conf if you have the issue with sessions and error 500 
#if [ -e "/opt/splunk/etc/apps/sessions.py" ]; then
#  cp -p /opt/splunk/lib/python3.7/site-packages/splunk/appserver/mrsparkle/lib/sessions.py /opt/splunk/etc/apps/sessions.py.orig
#  cp -p /opt/splunk/etc/apps/sessions.py /opt/splunk/lib/python3.7/site-packages/splunk/appserver/mrsparkle/lib/sessions.py 
#fi
sleep 1

if [ "$MODE" != "upgrade" ]; then 
  TODAY=`date '+%Y%m%d-%H%M_%u'`;
  echo "${TODAY}  splunkconf-cloud-recovery.sh checking if kvdump recovery running" >> /var/log/splunkconf-cloud-recovery-info.log
  # prevent reboot in the middle of a kvdump restore
  counter=100
  # (30 min max should be enough for restoring a big kvdump)
  while [ $counter -gt 0 ]
  do
    counter=$(($counter-1))
    if [ -e /opt/splunk/var/run/splunkconf-kvrestore.lock ]; then 
      echo "splunkconf-restore is running at the moment, waiting before initiating reboot (step=30s, counter=$counter)" >> /var/log/splunkconf-cloud-recovery-info.log
      sleep 30
    else
      # no need to loop
      break
    fi
  done
  # prevent stale lock 
  if [ -e /opt/splunk/var/run/splunkconf-kvrestore.lock ]; then 
    echo "Warning : Removing possible splunkconf kvstore lock" >> /var/log/splunkconf-cloud-recovery-info.log 
    rm /opt/splunk/var/run/splunkconf-kvrestore.lock
  fi
fi # if not upgrade


TODAY=`date '+%Y%m%d-%H%M_%u'`;
#NOW=`(date "+%Y/%m/%d %H:%M:%S")`
if [ "$MODE" != "upgrade" ]; then 
  if [ "${splunkosupdatemode}" = "disabled" ]; then
     echo "os update disabled, no need to reboot"
  elif [ "${splunkosupdatemode}" = "noreboot" ]; then
     echo "os update mode is no reboot , not rebooting"
  else
    echo "${TODAY} splunkconf-cloud-recovery.sh end of script, initiating reboot via init 6" >> /var/log/splunkconf-cloud-recovery-info.log
    # reboot
    init 6
  fi
else
  echo "${TODAY} splunkconf-cloud-recovery.sh end of script run in upgrade mode" >> /var/log/splunkconf-cloud-recovery-info.log
fi # if not upgrade
