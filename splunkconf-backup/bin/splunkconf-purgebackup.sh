#!/bin/bash
exec > /tmp/splunkconf-purgebackup-debug.log  2>&1


# in normal condition
#!/bin/bash
# only for very verbose debug
#!/bin/bash -x
# you may enable debug logging via config file or tag

# Copyright 2022 Splunk Inc.
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


# This script purge old backups according to your settings, current space used by backup, disk free space...
# Script will keep at least one version of each type
# This script is launched more frequently that backups in order to maximize chance of being to create newer backups even in starving disk conditions

# 20170123 purge script assoiated to backup script
# 20170123 renamed ending with splunk
# 20170131 force change dir to find envspl
# 20180620 updates to match backup updates
# 20181129 fix file names and typo for logging, add purge for state when rename from modinput
# 20190212 move to apps, add purge by size
# 20191001 give more explicit error message when remote backup dir os on s3
# 20191007 add purge for kvdump + other fixes
# 20191008 improve logging for purge by size, force bytes options to account for shell difference and default max size reduction
# 20191018 change exit code for not disabled backup to 0, relax name for purge to be able to purge from older versions when upgrading
# 20191021 make purge on size kvdump dir aware for local as in different directories (use find+ sort  instead of du)
# 20200304 improve logging, add local max size value check to avoid case of deleting all backup on invalid or too low value, add purge by retention for processed kvdump restored
# 20200318 add logic to avoid erasing the last backup of each type either because no new backup or no size (if something else use space or parameter too low, we will try our best until the admin figure out why
# 20200419 change size default
# 20200421 improve logging
# 20201105 add test for default and local conf file to prevent error appearing in logs
# 20220326 add support for rel and zstd types by relaxing form detection
# 20220326 change starving condition to fail even if that is probably du to external condition in order to try to be more visible that we have a problem + only log when all the types have been tried 
# 20220327 improve logging by adding freespace info
# 20230704 add rcp purge support
# 20230913 add more debug log for system local conf file
# 20231217 add lock file as can now be called through backup
# 20240301 fix regression with granular retention which was using the same setting for all types
# 20240623 add check_cloud function from backup , add variable and fix bug with purge for kvdump
# 20240629 replace direct var inclusion with loading function logic
# 20240701 add debugmode flag as arg to splunkconf-backup-helper
# 20230702 add more ec2 tag support taken from backup part

VERSION="20240702a"

###### BEGIN default parameters
# dont change here, use the configuration file to override them
# note : this script doesn't backup any index data

# get script dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR
# we are in bin
cd ..
# we are in the app dir
#pwd


# SPLUNK_HOME needs to be set
# if this is a link, use the real path here
#SPLUNK_HOME="/opt/splunk"
SPLUNK_HOME=`cd ../../..;pwd`

#### purge parameters

##### LOCAL

LOCALBACKUPDIR="${SPLUNK_HOME}/var/backups"

# number of days after which we completely remove backups
LOCALBACKUPRETENTIONDAYS=20
# number of days after which we remove most backups to free up space (this should be under the first parameter)
# idea is that we may have a high frequency backup for recent ones then we only keep a few (just in case, we want to go back to a old situation)
# NOT YET IMPLEMENTED
LOCALBACKUPRETENTIONDAYSPARTIAL=180
# KV
LOCALBACKUPKVRETENTIONDAYS=20
# scripts
LOCALBACKUPSCRIPTSRETENTIONDAYS=100
# modinput
LOCALBACKUPMODINPUTRETENTIONDAYS=7
LOCALBACKUPSTATERETENTIONDAYS=7

# ATTENTION : you need to free enough space or as the backup are now concurrent, one could eat the space and prevent the other one to run
# in all case, it is important to verify that backups are effectively running succesfully
# can be a number or value
LOCALMAXSIZE=8100000000 
#5G
#LOCALMAXSIZE=2000000000 #2G
# LOCALMAXSIZEDEFAULT is used when LOCALMAXSIZE set to auto as a failover valuye when needed
LOCALMAXSIZEDEFAULT=8100000000 

##### REMOTE 
# number of days after which we completely remove backups
REMOTEBACKUPRETENTIONDAYS=180
# number of days after which we remove most backups to free up space (this should be under the first parameter)
# idea is that we may have a high frequency backup for recent ones then we only keep a few (just in case, we want to go back to a old situation)
# NOT YET IMPLEMENTED
REMOTEBACKUPRETENTIONDAYSPARTIAL=180
# KV
REMOTEBACKUPKVRETENTIONDAYS=60
# scripts
REMOTEBACKUPSCRIPTSRETENTIONDAYS=200
# modinput
REMOTEBACKUPMODINPUTRETENTIONDAYS=7
REMOTEBACKUPSTATERETENTIONDAYS=7

REMOTEMAXSIZE=100000000000 #100G


# logging
# file will be indexed by local splunk instance
# allowing dashboard and alerting as a consequence
LOGFILE="${SPLUNK_HOME}/var/log/splunk/splunkconf-backup.log"

###### END default parameters
SCRIPTNAME="splunkconf-purgebackup"


###### function definition

function echo_log_ext {
  LANG=C
  #NOW=(date "+%Y/%m/%d %H:%M:%S")
  NOW=(date)
  echo `$NOW`" ${SCRIPTNAME} $1 " >> $LOGFILE
}

function debug_log {
  # set DEBUG=1 in conf file or splunkbackupdebug=1 via tag to enable debugging
  if [ -z ${splunkbackupdebug+x} ]; then
    splunkbackupdebug=0
  fi
  if [ -z ${DEBUG+x} ]; then
    DEBUG=0
  fi
  if [ "$DEBUG" == "1" ] || [ "$splunkbackupdebug" == "1" ] ; then
    echo_log_ext  "DEBUG id=$ID $1"
  fi
}

function echo_log {
  echo_log_ext  "INFO id=$ID $1"
}

function warn_log {
  echo_log_ext  "WARN id=$ID $1"
}

function fail_log {
  echo_log_ext  "FAIL id=$ID $1"
}

function splunkconf_checkspace {
  CURRENTAVAIL=`df --output=avail -k  ${LOCALBACKUPDIR} | tail -1`
  if [[ ${MINFREESPACE} -gt ${CURRENTAVAIL} ]]; then
    # we dont report the error here in normal case as it will be reported with nore info by the local backup functions
    debug_log "mode=$MODE, minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} type=localdiskspacecheck reason=insufficientspaceleft action=checkdiskfree result=fail ERROR : Insufficient disk space left , disabling backups ! Please fix "
    ERROR=1
    ERROR_MESS="localdiskspacecheck"
    return -1
  else
    debug_log "mode=$MODE, minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} type=localdiskspacecheck action=checkdiskfree result=success min free available OK"
    # dont touch ERROR here, we dont want to overwrite it
    return 0
  fi
}

function checklock() {
  if [ -e "${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock" ]; then
    count=$(/usr/bin/find "${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock" -mmin +${lockmindelay} -delete -print | wc -l) 
    if [ $count -gt 0 ]; then
       warn_log "ATTENTION: we had to remove stale lock file at "${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock" , this is unexpected, please investigate" 
    fi 
    if [ -e "${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock" ]; then
      ERROR=1
      ERROR_MESSAGE="${lockname}lock"
      fail_log ${lockmessage}
      exit 1
    fi
  fi
}

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
function check_cloud() {
  cloud_type=0
  response=$(curl -fs -m 5 -H "Metadata-Flavor: Google" ${METADATA_URL})
  if [ $? -eq 0 ]; then
    debug_log 'GCP instance detected'
    cloud_type=2
  # old aws hypervisor
  elif [ -f /sys/hypervisor/uuid ]; then
    if [ `head -c 3 /sys/hypervisor/uuid` == "ec2" ]; then
      debug_log 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # newer aws hypervisor (test require root)
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
      debug_log 'AWS instance detected'
      cloud_type=1
    fi
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "ec2" ]; then
      debug_log 'AWS instance detected'
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
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
    if [ -z ${TOKEN+x} ]; then
      # TOKEN NOT SET , NOT inside AWS
      cloud_type=0
    elif $(curl --silent -m 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone) ; then
      debug_log 'AWS instance detected'
      cloud_type=1
    fi
  fi
}

function load_settings_from_file () {
 FI=$1
 if [ -e "$FI" ]; then
   regclass="([a-zA-Z]+)[[:space:]]*=[[:space:]]*\"{0,1}([a-zA-Z0-9_\-]+)\"{0,1}"
   regclass2="^(#|\[)"
    # Read the file line by line, remove spaces then create a variable if start by splunk
    while read -r line; do
      if [[ "${line}" =~ $regclass2 ]]; then
        debug_log "comment line or stanza line with line=$line"
      elif [ -z "${line-unset}" ]; then
        debug_log "empty line"
      elif [[ "${line}" =~ $regclass ]]; then
        var_name=${BASH_REMATCH[1]}
        var_value=${BASH_REMATCH[2]}
        # Dynamically create the variable with its value
        declare -g "$var_name=$var_value"
        debug_log "OK:form ok, start with splunk setting $var_name=$var_value, $var_name=${!var_name}"
      else
        debug_log "KO:invalid form line=$line"
      fi
    done < $FI
  else
    debug_log "file $FI is not present"
  fi
}

###### start

# %u is day of week , we may use this for custom purge
TODAY=`date '+%Y%m%d-%H:%M_%u'`;
ID=`date '+%s'`;

debug_log "checking user is not root"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
 fail_log "This script must be run as splunk user, not root !" 1>&2
 exit 1
fi

debug_log "splunk_home=$SPLUNK_HOME "

SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"

# include VARs
APPDIR=`pwd`
debug_log "app=splunkconf-purgebackup result=running SPLUNK_HOME=$SPLUNK_HOME splunkconfappdir=${APPDIR} loading splukconf-backup.conf file"
if [[ -f "./default/splunkconf-backup.conf" ]]; then
#  . ./default/splunkconf-backup.conf
  load_settings_from_file ./default/splunkconf-backup.conf
  debug_log "INFO: splunkconf-backup.conf default succesfully included"
else
  debug_log "INFO: splunkconf-backup.conf default  not found or not readable. Using defaults from script "
fi

if [[ -f "./local/splunkconf-backup.conf" ]]; then
  #. ./local/splunkconf-backup.conf
  load_settings_from_file ./local/splunkconf-backup.conf
  debug_log "INFO: splunkconf-backup.conf local succesfully included"
else
  debug_log "INFO: splunkconf-backup.conf local not present, using only default"
fi
# take over over default and local
if [[ -f "${SPLUNK_HOME}/system/local/splunkconf-backup.conf" ]]; then
  load_settings_from_file ${SPLUNK_HOME}/system/local/splunkconf-backup.conf
  #. ${SPLUNK_HOME}/system/local/splunkconf-backup.conf && (echo_log "INFO: splunkconf-backup.conf system local succesfully included") 
else
  debug_log "INFO: splunkconf-backup.conf in system/local not present, no need to include it"
fi

#debug_log "INFO: MYVAR=$MYVAR, MYTEST=$MYTEST"

debug_log "checking for purge lock"
lockname="purge"
lockmindelay=5
lockmessage="splunkconf-purgebackup is currently running, stopping purgebackup to avoid conflic"
checklock;

`touch ${SPLUNK_HOME}/var/run/splunkconf-purge.lock`

LOCALKVDUMPDIR="${SPLUNK_DB}/kvstorebackup"

check_cloud
debug_log "cloud_type=$cloud_type"


# we get most var dynamically from ec2 tags associated to instance

# getting tokens and writting to instance-tags that we use 

CHECK=1

if ! command -v curl &> /dev/null
then
  warn_log "ERROR: oops ! command curl could not be found ! trying without by may be needed especially for cloud env"
  CHECK=0
fi

if ! command -v aws &> /dev/null
then
  debug_log "INFO: command aws not detected, assuming we are not running inside aws"
  CHECK=0
fi

INSTANCEFILE="${SPLUNK_HOME}/var/run/splunk/instance-tags"

if [ $CHECK -ne 0 ]; then
  if [[ "cloud_type" -eq 1 ]]; then
    # aws
    # setting up token (IMDSv2)
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
    # lets get the s3splunkinstall from instance tags
    INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
    REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `

    # we put store tags in instance-tags file-> we will use this later on
    aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/' | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' | grep -E "^splunk" > $INSTANCEFILE
    if grep -qi splunk $INSTANCEFILE
    then
      # note : filtering by splunk prefix allow to avoid import extra customers tags that could impact scripts
      debug_log "filtering tags with splunk prefix for instance tags (file=$INSTANCEFILE)"
    else
      debug_log "splunk prefixed tags not found, reverting to full tag inclusion (file=$INSTANCEFILE)"
      aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/' | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' > $INSTANCEFILE
    fi
  fi
elif [[ "cloud_type" -eq 2 ]]; then
  # GCP
  splunkinstanceType=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkinstanceType`
  if [ -z ${splunkinstanceType+x} ]; then
    debug_log "GCP : Missing splunkinstanceType in instance metadata"
  else
    # > to overwrite any old file here (upgrade case)
    echo -e "splunkinstanceType=${splunkinstanceType}\n" > $INSTANCEFILE
  fi
  splunks3installbucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3installbucket`
  if [ -z ${splunks3installbucket+x} ]; then
    debug_log "GCP : Missing splunks3installbucket in instance metadata"
  else
    echo -e "splunks3installbucket=${splunks3installbucket}\n" >> $INSTANCEFILE
  fi
  splunks3backupbucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3backupbucket`
  if [ -z ${splunks3backupbucket+x} ]; then
    debug_log "GCP : Missing splunks3backupbucket in instance metadata"
  else
    echo -e "splunks3backupbucket=${splunks3backupbucket}\n" >> $INSTANCEFILE
  fi
  splunks3databucket=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3databucket`
  if [ -z ${splunks3databucket+x} ]; then
    debug_log "GCP : Missing splunks3databucket in instance metadata"
  else
    echo -e "splunks3databucket=${splunks3databucket}\n" >> $INSTANCEFILE
  fi
  splunklocalbackupretentiondays=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalbackupretentiondays`
  splunklocalbackupkvretentiondays=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalbackupkvretentiondays`
  splunklocalbackupscriptsretentiondays=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalbackupscriptsretentiondays`
  splunklocalbackupstateretentiondays=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalbackupstateretentiondays`
  splunklocalbackupdir=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalbackupdir`
  splunklocalmaxsize=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalmaxsize`
  splunklocalmaxsizeauto=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunklocalmaxsizeauto`

else
  warn_log "aws cloud tag detection disabled (missing commands)"
fi
if [ -e "$INSTANCEFILE" ]; then
  chmod 644 $INSTANCEFILE
  # including the tags for use in this script
  . $INSTANCEFILE
  # note : if the tag detection failed , file may be empty -> we are still checking after
fi


# At this point we get var with combination from tags, conf file , default 
if [ "$DEBUG" == "1" ] || [ "$splunkbackupdebug" == "1" ] ; then
  DEBUG=1
  # make DEBUG variable consistent with tag so we can use it as arg for helper script
fi

# used for trim
shopt -s extglob
if [ ! -z ${splunklocalbackupretentiondays+x} ]; then 
  splunklocalbackupretentiondays=${splunklocalbackupretentiondays##+( )}
  splunklocalbackupretentiondays=${splunklocalbackupretentiondays%%+( )}
  if [ ${splunklocalbackupretentiondays} -gt 0 ]; then 
    LOCALBACKUPRETENTIONDAYS=${splunklocalbackupretentiondays}
    debug_log "set LOCALBACKUPRETENTIONDAYS=$LOCALBACKUPRETENTIONDAYS from tag"
  fi
fi 

if [ ! -z ${splunklocalbackupkvretentiondays+x} ]; then 
  splunklocalbackupkvretentiondays=${splunklocalbackupkvretentiondays##+( )}
  splunklocalbackupkvretentiondays=${splunklocalbackupkvretentiondays%%+( )}
  if [ ${splunklocalbackupkvretentiondays} -gt 0 ]; then 
    LOCALBACKUPKVRETENTIONDAYS=${splunklocalbackupkvretentiondays}
    debug_log "set LOCALBACKUPKVRETENTIONDAYS=$LOCALBACKUPKVRETENTIONDAYS from tag"
  fi
fi 

if [ ! -z ${splunklocalbackupscriptsretentiondays+x} ]; then 
  splunklocalbackupscriptsretentiondays=${splunklocalbackupscriptsretentiondays##+( )}
  splunklocalbackupscriptsretentiondays=${splunklocalbackupscriptsretentiondays%%+( )}
  if [ ${splunklocalbackupscriptsretentiondays} -gt 0 ]; then 
    LOCALBACKUPSCRIPTSRETENTIONDAYS=${splunklocalbackupscriptsretentiondays}
    debug_log "set LOCALBACKUPSCRIPTSRETENTIONDAYS=$LOCALBACKUPSCRIPTSRETENTIONDAYS from tag"
  fi
fi 

if [ ! -z ${splunklocalstatebackupretentiondays+x} ]; then 
  splunklocalbackupstateretentiondays=${splunklocalbackupstateretentiondays##+( )}
  splunklocalbackupstateretentiondays=${splunklocalbackupstateretentiondays%%+( )}
  if [ ${splunklocalbackupstateretentiondays} -gt 0 ]; then 
    LOCALBACKUPSTATERETENTIONDAYS=${splunklocalbackupstateretentiondays}
    debug_log "set LOCALBACKUPSTATERETENTIONDAYS=$LOCALBACKUPSTATERETENTIONDAYS from tag"
  fi
fi 

if [ ! -z ${splunklocalbackupdir+x} ]; then 
  splunklocalbackupdir=${splunklocalbackupdir##+( )}
  splunklocalbackupdir=${splunklocalbackupdir%%+( )}
  if [ -e ${splunklocalbackupdir} ]; then 
    LOCALBACKUPDIR=${splunklocalbackupdir}
    debug_log "set LOCALBACKUPDIR=$LOCALBACKUPDIR from tag"
  else
    warn_log "invalid directory in tag splunklocalbackupdir=$splunklocalbackupdir, ignoring"
  fi
fi 

if [ ! -z ${splunklocalmaxsize+x} ]; then 
  splunklocalmaxsize=${splunklocalmaxsize##+( )}
  splunklocalmaxsize=${splunklocalmaxsize%%+( )}
  if [ ${splunklocalmaxsize} -gt 0 ]; then 
    LOCALMAXSIZE=${splunklocalmaxsize}
    debug_log "set LOCALMAXSIZE=$LOCALMAXSIZE from tag"
  fi
fi 

if [ ! -z ${splunklocalmaxsizeauto+x} ]; then 
  splunklocalmaxsizeauto=${splunklocalmaxsizeauto##+( )}
  splunklocalmaxsizeauto=${splunklocalmaxsizeauto%%+( )}
  if [ ${splunklocalmaxsizeauto} -gt 0 ]; then 
    LOCALMAXSIZEAUTO=${splunklocalmaxsizeauto}
    debug_log "set LOCALMAXSIZEAUTO=$LOCALMAXSIZEAUTO from tag"
  fi
fi 

if [ -z ${LOCALBACKUPRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPRETENTIONDAYS. Exiting !"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPRETENTIONDAYS defined and set to ${LOCALBACKUPRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPKVRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPKVRETENTIONDAYS. Exiting !"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPKVRETENTIONDAYS defined and set to ${LOCALBACKUPKVRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPSCRIPTSRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPSCRIPTSRETENTIONDAYS. Exiting !"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPSCRIPTSRETENTIONDAYS defined and set to ${LOCALBACKUPSCRIPTSRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPMODINPUTRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPMODINPUTRETENTIONDAYS. Exiting !"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPMODINPUTRETENTIONDAYS defined and set to ${LOCALBACKUPMODINPUTRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPSTATERETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPSTATERETENTIONDAYS. Exiting !"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPSTATERETENTIONDAYS defined and set to ${LOCALBACKUPSTATERETENTIONDAYS}"; fi
if [ -z ${SPLUNK_HOME+x} ]; then fail_log "SPLUNK_HOME not defined  !!!!"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "SPLUNK_HOME defined to ${SPLUNK_HOME}"; fi
if [ -z ${LOCALBACKUPDIR+x} ]; then fail_log "LOCALBACKUPDIR not defined !!!!"; `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`;exit 1; else debug_log "LOCALBACKUPDIR defined and set to ${LOCALBACKUPDIR}"; fi
if (( ${LOCALMAXSIZE} > 1000000000 )); then 
  debug_log "LOCALMAXSIZE=${LOCALMAXSIZE} value check ok" 
elif [ ${LOCALMAXSIZE} = "auto" ]; then
  # FIXME add more logic here
  LOCALMAXSIZE=${LOCALMAXSIZEAUTO}
else 
  fail_log "LOCALMAXSIZE=${LOCALMAXSIZE} value check KO ! Need to be at least 1G(1000000000). Exiting to avoid deletion of all backups on invalid value"
  debug_log "removing lock file so other purgebackup process may run"
  `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`
  exit 1;
fi

splunkconf_checkspace

# -delete option to find does the delete

# LOCAL
# this contain the latest versions of backup so we dont erase them even in low disk conditions
TYPE="local"
EXCLUSION_LIST=""

REASON="age" 
# etc
BACKUPDIR=${LOCALBACKUPDIR}
OBJECT="etc"
RETENTIONDAYS=${LOCALBACKUPRETENTIONDAYS}
A=`ls -tr ${BACKUPDIR}/backupconfsplunk-*${OBJECT}*tar.*| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "
# || fail_log "action=purge type=local reason=retentionpolicy object=etc result=fail error purging local etc backup "

splunkconf_checkspace

# kv tar version
BACKUPDIR=${LOCALBACKUPDIR}
OBJECT="kvstore"
RETENTIONDAYS=${LOCALBACKUPKVRETENTIONDAYS}
A=`ls -tr ${BACKUPDIR}/backupconfsplunk-*${OBJECT}*tar.*| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "

splunkconf_checkspace

# Attention LOCALKVDUMPDIR used here
# kv dump version
BACKUPDIR=${LOCALKVDUMPDIR}
OBJECT="kvdump"
RETENTIONDAYS=${LOCALBACKUPKVRETENTIONDAYS}
A=`ls -tr ${BACKUPDIR}/backupconfsplunk-*${OBJECT}*tar.*| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "

splunkconf_checkspace

# scripts
BACKUPDIR=${LOCALBACKUPDIR}
OBJECT="scripts"
RETENTIONDAYS=${LOCALBACKUPSCRIPTSRETENTIONDAYS}
A=`ls -tr ${BACKUPDIR}/backupconfsplunk-*${OBJECT}*tar.*| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "

splunkconf_checkspace

# modinput (for upgrade, newer version only create state)
BACKUPDIR=${LOCALBACKUPDIR}
OBJECT="modinput"
RETENTIONDAYS=${LOCALBACKUPMODINPUTRETENTIONDAYS}
A="na"
# we may remove all versions after retention as we will now have state
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "

splunkconf_checkspace

# state
BACKUPDIR=${LOCALBACKUPDIR}
OBJECT="state"
RETENTIONDAYS=${LOCALBACKUPSTATERETENTIONDAYS}
A=`ls -tr ${BACKUPDIR}/backupconfsplunk-*${OBJECT}*tar.*| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${BACKUPDIR} -type f \( -name "backupconfsplunk-*${OBJECT}*tar.*" ! -wholename $A \) -mtime +${RETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${RETENTIONDAYS} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} "

# delete on size
REASON=size
CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump* | cut -f1 | tail -1`
#LASTSIZE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f -name "*.tar.gz" -printf '%Cs %p\n'|sort -rn | tail -1`
#CURRENTSIZE=`echo ${LASTSIZE} | cut -d ' ' -f 1`
debug_log "checking purge on size action=checksize currentlocalsize=${CURRENTSIZE},currentmaxlocalsize=${LOCALMAXSIZE} EXCLUSION_LIST=${EXCLUSION_LIST} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL}"
EXITSIZE=0
while [ ${CURRENTSIZE} -gt ${LOCALMAXSIZE} ];
do
  EXITSIZE=0    # at each round we start by 0 then if all backup type just have one remaining and we are still starving we will exit anyway 
  debug_log " in current size loop, need to purge !"
  #OLDESTFILE=`ls -t ${LOCALBACKUPDIR}/backup* | tail -1`;
  #OLDESTFILE=`echo ${LASTSIZE} | cut -d ' ' -f 2 | tail -1`;
  for OBJECT in "etc" "scripts" "kvstore" "kvdump" "modinput" "state"; 
  do
    debug_log " in current size and object (${OBJECT}) loop"
    OLDESTFILE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f \( -name "*${OBJECT}*.tar.*" ${EXCLUSION_LIST} \) -printf '%Cs %p\n'|sort -rn | cut -d ' ' -f 2 | tail -1`
    OLDESTFILE=${OLDESTFILE:-"na"}
    if [ -e ${OLDESTFILE} ]; then
      rm -f ${OLDESTFILE}  && RES="success" || RES="failure";
      CURRENTSIZEPRE=${CURRENTSIZE}
      CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump*| cut -f1 | tail -1`
      # in case of purge by size, we get available free space after purging which is better
      splunkconf_checkspace

      echo_log "action=purge type=$TYPE reason=$REASON object=${OBJECT} dest=${OLDESTFILE}  localsizepre=${CURRENTSIZEPRE} localsize=${CURRENTSIZE} maxlocalsize=${LOCALMAXSIZE} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} result=$RES"
      #LASTSIZE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f -name "*.tar.gz" -printf '%Cs %p\n'|sort -rn | tail -1`
      #CURRENTSIZE=`echo ${LASTSIZE} | cut -d ' ' -f 1`
      debug_log "checking purge on size action=checksize currentlocalsize=${CURRENTSIZE},currentmaxlocalsize=${LOCALMAXSIZE} , OBJECT=${OBJECT} "
    else
      CURRENTSIZEPRE=${CURRENTSIZE}
      CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump*| cut -f1 | tail -1`
      # we must exit loop, we cant purge more
      let "EXITSIZE=EXITSIZE+1"
      debug_log "just increased existsize to ${EXITSIZE}, OBJECT=${OBJECT}"
      continue;
    fi
  done
  # potential max value is 6 currently
  if [ ${EXITSIZE} -gt 5 ]; then
    debug_log "forwarding starving condition size exit to underlying loop"
    splunkconf_checkspace
    # we only log once in that case
    fail_log "action=nopurge type=$TYPE reason=$REASON localsizepre=${CURRENTSIZEPRE} localsize=${CURRENTSIZE} maxlocalsize=${LOCALMAXSIZE} result=\"starving-nopurgebackupcandidate\" minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL}"
    # alternatively we could add a condition to while
    break;
  else 
    debug_log "not in starving condition, EXITSIZE=${EXITSIZE}, continuing through normal loop"
  fi  
done;


################ REMOTE 

TYPE="remote"


# note : only implemented for nas type currently, implicitely you have use the date versioned files for this to work correctly
if [ -z ${REMOTEBACKUPDIR+x} ]; then 
  debug_log "REMOTEBACKUPDIR not defined, remote purge disabled";
  debug_log "removing lock file so other purgebackup process may run"
  `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`
  exit 0;
elif [[ ${REMOTEBACKUPDIR} == s3* ]] ; then
  # by design, we should not be able to delete here
  debug_log "REMOTEBACKUPDIR is on s3, remote purge disabled, please use lifecycle policy in object store to remove oldest versions"; 
  debug_log "removing lock file so other purgebackup process may run"
  `rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`
  exit 0;
else
  debug_log "REMOTEBACKUP"
  # adding instance name , we only want to purge the data for this instance !
  SERVERNAME=`grep serverName ${SPLUNK_HOME}/etc/system/local/server.conf  | awk '{print $3}'`
  # servername is more reliable ithan host in dynamic env like AWS
  INSTANCE=$SERVERNAME
  REMOTEBACKUPDIR="${REMOTEBACKUPDIR}/${INSTANCE}"
  debug_log "INSTANCE=${INSTANCE}, REMOTEBACKUPDIR=${REMOTEBACKUPDIR} REMOTETECHNO=${REMOTETECHNO}"
  if (( REMOTETECHNO == 3 )); then
    debug_log "purge on remote rcp"
    CPCMD="scp";
    # second option depend on recent ssh , instead it is possible to disable via =no or use other mean to accept the key before the script run
    OPTION="-oConnectTimeout=30 -oServerAliveInterval=60 -oBatchMode=yes -oStrictHostKeyChecking=accept-new";
    RESSCPPU=`scp $OPTION  ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-purgebackup-helper.sh ${RCPREMOTEUSER}@${RCPHOST}: `
    RESMKDIR=`ssh $OPTION  ${RCPREMOTEUSER}@${RCPHOST} ./splunkconf-purgebackup-helper.sh $REMOTEBACKUPDIR $REMOTEBACKUPRETENTIONDAYS $REMOTEMAXSIZE $DEBUG` 
  elif [ -d "${REMOTEBACKUPDIR}" ]; then
    debug_log "Starting to purging old backups"
# FIXME : reuse exclusion_list logic to always keep one backup for remote nas condition
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*etc*tar.*" -mtime +${REMOTEBACKUPRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=etc result=success purge remote etc backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=etc result=fail   error purging remote etc backup "
    # kv tar
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*kvstore*tar.*" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvstore result=success purge remote kv backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvstore result=fail  error purging remote kv backups"
    # kv dump
    # note after a restore the file end by tar.gz.processed, we still want to clean it up after a while
    /usr/bin/find ${REMOTEKVDUMPDIR} -type f -name "backupconfsplunk-*kvdump*tar.*" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvdump result=success purge remote kv dump done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvdump result=fail error purging remote kv dump"
    # scripts
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*script*tar.*" -mtime +${REMOTEBACKUPSCRIPTSRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=scripts result=success purge remote scripts backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=scripts result=fail error purging remote scripts backup"
    # modinput (upgrade case)
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*modinput*tar.*" -mtime +${REMOTEBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=modinput result=success purge remote modinput backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=modinput result=fail error purging remote modinput backup"
    # state
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*state*tar.*" -mtime +${REMOTEBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=state result=success purge remote state backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=state result=fail error purging remote state backup"

    # delete on size, we try to delete a whole set of backups so we hopefully have enough space for a new whole set of backups 
    while [ `du -c ${REMOTEBACKUPDIR}/backup* | cut -f1 | tail -1` -gt ${REMOTEMAXSIZE} ];
    do 
      #OBJECT
      OLDESTFILE=`ls -t ${REMOTEBACKUPDIR}/backup* | tail -n1`;
      rm -f ${OLDESTFILE} && echo_log "action=purge type=$TYPE reason=size file=${OLDESTFILE} result=success" ||  fail_log "action=purge type=remote reason=size file=${OLDESTFILE} result=fail"
    done;
    debug_log "End purging old backups"
  else
    debug_log "nothing to purge, remote backup dir ${REMOTEBACKUPDIR} not found"
  fi
fi

debug_log "removing lock file so other purgebackup process may run"
`rm ${SPLUNK_HOME}/var/run/splunkconf-${lockname}.lock`
