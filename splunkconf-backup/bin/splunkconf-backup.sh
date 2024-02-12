#!/bin/bash -x
exec > /tmp/splunkconf-backup-debug.log  2>&1

# in normal condition
#!/bin/bash
# only for really verbose debug
#!/bin/bash -x
# you can enable debug log via config file or tag


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


##/bin/env > /tmp/debugenv

# This script backup splunk config files, state , scripts and kvstore 

# 201610 initial
# 20170123 move to use ENVSPL, add kvstore backup
# 20170123 small fixes, disabling etc selective backup by default as we do full etc
# 20170131 force change dir to find envspl
# 20170515 add host in filename
# 20180528 add instance.cfg,licences, ... when not using a full version
# 20180619 move to subdirectory backup and specific configuration file for parameters
# 20180705 add scheduler state (DM accel state and scheduler suppression, to avoid breaking throttling (used by ES))
# 20180816 change servername detection to call splunk command to avoid some false positives 
# 20180906 add remote option 3 for scp
# 20190129 add automatic version detection to use online kvstore backup
# 20190212 move to splunk apps (lots of changes)
# 20190404 add exclude for etc backup for case where temo files in apps dir
# 20190401 add system local support
# 20190926 add more state files
# 20190927 prevent conflict between python version and commands like aws which need to use the system shipped python
# 20190927 change storage class for backup to hopefully optimize costs
# 20190929 use ec2-data when available so that we dont need to set in conf files the s3 bucket location
# 20191001 add more exclusion to exclude files shipped with splunk from etc backup (to avoid overriding after upgrade)
# 20191006 finalize online kvstore backup
# 20191007 change kvdump name to be consistent with purging
# 20191008 add minspaceavailable protection, improve logging and tune default
# 20191010 more logging improvements
# 20191018 correct exit codes to have ES checks happy, change version test to less depend on external command, change manageport detection that dont work on all env, reduce tar kvstore loop try as we have kvdump
# 20200304 add logic for more generic /etc/instance-tags for non aws case + more logging improvements and move lots of logging to debug levea, fix statelist var in log message
# 20200309 disable old tar kvstore when doing kvdump, more logging improvements
# 20200314 add restore lock check to avoid launching a backup while a restore is still running (big kvdump for example) (may be theorically possible but add load to kvstore and not really make sense) 
# 20200318 add ability to pass parameter for specific backup only in order to do more fine grained scheduling
# 20200502 change disk space check to not exit immediately in order to report more info for backup that are missing (to be used for reporting logic)
# 20200502 make code more modular, improve logging for full etc case, add disabled apps dir to targeted etc, set umask explicitely, change check for kvstore remote copy  
# 20200504 add timezone info in backup filename to ease reporting from splunk
# 20200623 add splunk prefix logic on var got from instance tags
# 20200721 fix typo in statelist (missing space)
# 20200908 include AWS tags directly in for case where recovery script not (yet) deployed
# 20200909 change path for instance tags so that it can work as splunk user with no additional permissions
# 20201011 instance tags prefix detection fix (adapted from same fix in recovery)
# 20201012 add /bin to PATH as required for AWS1, fix var name for kvstore remote s3 (7.0)
# 20201105 add test for default and local conf file to prevent error appearing in logs
# 20201106 remove any extra spaces in tags around the = sign
# 20210127 add GCP support
# 20210202 add fallback to /etc/instance-tags for case where dynamic tags are not working but the files has been set by another way
# 20210202 use splunkinstanceType before servername before host for instancename 
# 20210729 add imdsv2 to aws cloud detection
# 20211124 comment debug command, include license wording, add initial options for rsync
# 20220102 fix cloud detection for newer AWS kernels
# 20220322 improve tag space autodetection
# 20220322 code factorization to ease support tar format change
# 20220323 add manager-apps dir (for cm)
# 20220325 improve file detection to remove false warning from tar
# 20220326 reduce log verbosity for cloud detection 
# 20220326 add distinct extension for kvdump (as of now splunk will generate as gz)
# 20220326 add rel mode and default to it
# 20220327 fix test condition regression for etc targeted and regular conf files
# 20220327 add also size and duration for kvstore legacy mode
# 20220327 factor remote copy in order to add duration and size to log
# 20220409 fix double remote copy issue with kvdump/kvstore 
# 20220823 fix regression for cm master and manager folders 
# 20221014 remove logging for remote when unconfigured (to reduce logging footprint)
# 20230202 optimize renote copy, change logic condition when disabled to imprive logging experience, enable disabled logging to allow dashboard to differentiate missing and disabled state, change logic so that with remote disabled, we now log a disabled entry which make easier to report on dashboard
# 20230206 add autodisable for scripts, uf detection, autokvdump disable for uf or kvstore disabled, add logic for empty statelist case with specific log, fix missing var for 2 dir in statelist (rel mode)
# 20230208 add action to some log entries 
# 20230327 fix typo in modinputs path
# 20230703 add more logic for rsync mode
# 20230913 fix system local detection and add debug log when not existing
# 20230913 fix debug message for clone conflict situation in rsync mode
# 20230913 fix variables for rsync mode
# 20231204 add mode for init
# 20231207 make REMOTES3STORAGECLASS a variable with default value STANDARD_IA
# 20231208 add more settings and new mode to leverage s3api put-object instead of s3 cp as it will allow to use tags
# 20231210 add initial tags for s3 
# 20231211 add frequency tag + add call to purgebackup before each backup for init mode + remove random delay at start for init mode
# 20231213 use different storage class depending on frequency 
# 20231212 REMOTESTORAGE auto arg check fix
# 20231214 padding fix for date comamnd (for frequency feature)
# 20231216 stale lock prevention added
# 20231219 add setting to allow disabling tagging for s3 
# 20240126 add endpoint s3 option for s3 compliant destinations
# 20240129 add more logging for endpoint-url setting
# 20240130 more endpoint-url support and fixes
# 20240212 add splunks3endpointurl tag support to allow test automation 
# 20240212 fix logic for splunks3endpointurl versus conf file + add splunkrsyncautorestore tag support

VERSION="20240212b"

###### BEGIN default parameters 
# dont change here, use the configuration file to override them
# note : this script wont backup any index data

# Note : we can be called either from splunk via a input or via direct call 
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
#SPLUNK_HOME=`cd ../../..;pwd`
SPLUNK_HOME=`cd ../../..;pwd`
# note : we could get this from env now when we run via input

# debug -> verify the env that splunk set (python version may affect aws command for example,...)
#env
# unsetting env to not depend on splunk python version 
# this is because we may call aws command which is in python itself and can break du to this
unset LD_LIBRARY_PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin
unset PYTHONHASHSEED
unset NODE_PATH
unset PYTHONPATH
#env

# umask
umask 027
# splunk can read/write backups
# group can access backup (should be splunk group)
# other should not access backups

# we always do relative backup but if ever you want the old way, change mode below to abs
# recovery part support both mode 
# du to recent tar behavior related to exclusion it is better to use rel mode
TARMODE="rel"
# this is the form that gets added in name if the backup was made relative to splunk home
# otherwise no extension
extmode="rel-"
backuptardir="${SPLUNK_HOME}"
if [ "${TARMODE}" = "abs" ]; then
     extmode=""
     backuptardir="/"
fi
#FI="backupconfsplunk-${extmode}${type}.tar.${compress}"

# FIXME , get it automatically from splunk-launch.conf 
SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"
SPLUNK_DB_REL="./var/lib/splunk"


# backup type selection 
# 1 = targeted etc -> use a list of directories and files to backup
# 2 = full etc   (bigger)
# default to targeted etc
BACKUPTYPE=1

# LOCAL AND REMOTE BACKUP options

# LOCAL options
# NOT used this is enforced ! DOLOCALBACKUP=1
# type : 1 = date versioned backup (preferred for local),2 = only one backup file with instance name in it (dangerous, we need other feature to do versioning like filesystem (btrfs) , classic backup on top, ...  3 = only one backup, no instance name in it (tehy are still sorted by instance directory, may be easier for automatic reuse by install scripts)
LOCALTYPE=1
# where to store local backups
# depending on partitions
# splunk user should be able to write to this directory
LOCALBACKUPDIR="${SPLUNK_HOME}/var/backups"
# Reserve enough space or backups will fail ! IMPORTANT
# see below for check on min free space

# REMOTE options
# enabled by default , try to get s3 bucket info from ec2 tags or just do nothing
DOREMOTEBACKUP=1
# exemple, please tune
# PLEASE USE A SUBDIRECTORY ON THE REMOTE LOCATION SO THAT THE DIRECTORY CHECK WILL FAIL IN CASE THE REMOTE STORAGE IS NOT THERE (we don't want to write locally if not mouted for example)
#REMOTEBACKUPDIR="/mnt/remotenas/backup"
REMOTEBACKUPDIR="s3://pleaseconfigurenstancetagsorsetdirectlythes3bucketforbackupshere-splunks3splunkbackup/splunkconf-backup"
# type 1 = nas (use cp), 2 = S3 (use aws s3 cp) or GCS , 3= remote nas via scp, 4 = rsync
REMOTETECHNO=2
# type : 0=auto 1 = date versioned backup (preferred for local),2 = only one backup file (dangerous, we need other feature to do versioning like filesystem (btrfs) , classic backup on top, ... 3 = only one backup, no instance name in it (they are still sorted by instance directory, may be easier for automatic reuse by install scripts)
# auto -> S3 =0 (because s3 can store multiple versions of same file), NAS=1
REMOTETYPE=0

#REMOTES3STORAGECLASS="STANDARD_IA"
REMOTES3STORAGECLASS="auto"

# STD as we keep it less than 30 days
#REMOTES3STORAGECLASSHOURLY="STANDARD"
REMOTES3STORAGECLASSHOURLY="auto"

#REMOTES3STORAGECLASSDAILY="STANDARD-IA"
REMOTES3STORAGECLASSDAILY="auto"

#REMOTES3STORAGECLASSWEEKLY="STANDARD-IA"
REMOTES3STORAGECLASSWEEKLY="auto"

#REMOTES3STORAGECLASSMONTHLY="STANDARD-IA"
REMOTES3STORAGECLASSMONTHLY="auto"

# by default we will tag objects send to s3, set this to 0 to disable it 
REMOTEOBJECTSTORETAGS3="1"

# you dont need to set this unless doing backup to object store on prem 
# it is better to use tag on instance metadata so the app config is the same between different env
REMOTEOBJECTSTOREBUCKET="auto"
# this is the prefix
REMOTEOBJECTSTOREPREFIX="splunkconf-backup"

# 0 = auto (2 at the moment)
# 1 = use aws s3 cp (no support for tags)
# 2 = use aws s3-apui copy-object (support tags)

# for on prem s3, specify the endpoint url as http(s)://mys3endpoint , otherwise let the auto setting
# this will add  --endpoint-url $REMOTES3ENDPOINTURL to aws commands
REMOTES3ENDPOINTURL="auto"

AWSCOPYMODE=0

# RSYNC OVER SSH options
# RSYNCMODE

# enable autorestore via rsync over ssh
RSYNCAUTORESTORE=1

# WHAT TO BACKUP
# this can be used for : rollback, doing diff , moving conf to new server, ....
# this is not meant to backup files binaries, var , index, ....
# you should backup the backup ie not just keep it local to avoid the server has crashed and the script deleting the backups....
# set to activate backups
BACKUP=1
# set to backup kvstore
BACKUPKV=1
# set to backup scheduler state, modinput (hf but also useful on sh for dm and throttling) 
BACKUPSTATE=1
# set to backup scripts
BACKUPSCRIPTS=1


# KVSTORE Backup options
# stop splunk for kvstore backup (that can be a bad idea if you have cluster and stop all instances at same time or whitout maintenance mode)
# risk is that data could be corrupted if something is written to kvstore while we do the backup
#RESTARTFORKVBACKUP=1
# default path, change if you need, especially if you customized splunk_db
if [ "${TARMODE}" = "abs" ]; then
  KVDBPATH="${SPLUNK_DB}/kvstore"
else
  KVDBPATH="${SPLUNK_DB_REL}/kvstore"
fi

# fixme : move this after so that splunk_home changes apply
# state files and dir
#MODINPUTPATH="${SPLUNK_DB}/modinputs"
#SCHEDULERSTATEPATH="${SPLUNK_HOME}/var/run/splunk/scheduler"
if [ "${TARMODE}" = "abs" ]; then
    STATELIST="${SPLUNK_DB}/modinputs ${SPLUNK_HOME}/var/run/splunk/scheduler ${SPLUNK_HOME}/var/run/splunk/cluster/remote-bundle ${SPLUNK_DB}/persistentstorage ${SPLUNK_DB}/fishbucket ${SPLUNK_HOME}/var/run/splunk/deploy"
else
    STATELIST="${SPLUNK_DB_REL}/modinputs ./var/run/splunk/scheduler ./var/run/splunk/cluster/remote-bundle ${SPLUNK_DB_REL}/persistentstorage ${SPLUNK_DB_REL}/fishbucket ./var/run/splunk/deploy"
fi

# configuration for scripts backups
# script dir (what to backup)
if [ "${TARMODE}" = "abs" ]; then
    SCRIPTDIR="${SPLUNK_HOME}/scripts"
else
    SCRIPTDIR="./scripts"
fi

#minfreespace

# 5000000 = 5G
MINFREESPACE=4000000

# logging
# file will be indexed by local splunk instance
# allowing dashboard and alerting as a consequence
LOGFILE="${SPLUNK_HOME}/var/log/splunk/splunkconf-backup.log"


###### END default parameters
SCRIPTNAME="splunkconf-backup"


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
    DA=`date`
    echo_log_ext  "DEBUG $DA id=$ID $1"
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


function splunkconf_purgebackup { 
  debug_log "calling purge backup in order to maximize space avaialble before doing new backup"
  ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-purgebackup.sh
} 

function splunkconf_checkspace { 
  CURRENTAVAIL=`df --output=avail -k  ${LOCALBACKUPDIR} | tail -1`
  if [[ ${MINFREESPACE} -gt ${CURRENTAVAIL} ]]; then
    # we dont report the error here in normal case as it will be reported with nore info by the local backup functions
    debug_log "action=checkdiskfree mode=$MODE, minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} type=localdiskspacecheck reason=insufficientspaceleft result=fail ERROR : Insufficient disk space left , disabling backups ! Please fix "
    ERROR=1
    ERROR_MESS="localdiskspacecheck"
    return -1
  else
    debug_log "action=checkdiskfree mode=$MODE, minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} type=localdiskspacecheck result=success min free available OK"
    # dont touch ERROR here, we dont want to overwrite it
    return 0
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

# at start we check what compression we can use
# at the moment this is mainly zstd
function check_compress() {
    COMPRESS="gzip"
    EXTENSION="gz"
    # if zstd command is present, better to choose zstd
    # note that you may use yum install zstd or equivalent to have this command available
    if command -v zstd &> /dev/null
    then
        COMPRESS="zstd"
        EXTENSION="zst"
    fi
    debug_log "Compression method will be ${COMPRESS}";
}

function do_backup_tar() {
    # inputs : MODE FIC FILELIST TYPE OBJECT MESS1 TARMODE COMPRESSMODE
    # MODE can be etc etctargeted scripts state
    # OBJECT can be etc scripts state   (the only difference is for etctargeted versus etc (full))
    # FIC is tar filename
    # EXCLUDELIST ref to a exclude list file
    # EXCLUDEFORM
    # FILELIST contain list of files to tar for this mode
    # MESS1
    # TARMODE is either absolute (original mode) or relative (future)
    # COMPRESSMODE is either gzip (original) or other compression algo (future)
    debug_log "running tar for ${MODE} backup";

    if [ "$MODE" == "etc" ]; then
         PARAMEXCLUDE=" --exclude-from=${TAREXCLUDEFILE} --exclude '*/dump'"
    else
         PARAMEXCLUDE=""
    fi
    debug_log "running tar -I ${COMPRESS} -C${backuptardir} -cf ${FIC} ${PARAMEXCLUDE} ${FILELIST}";
    START=$(($(date +%s%N)));
    tar -I ${COMPRESS} -C${backuptardir} -cf ${FIC} ${PARAMEXCLUDE} ${FILELIST} 
    RES=$?
    END=$(($(date +%s%N)));
    #let DURATIONNS=(END-START)
    let DURATION=(END-START)/1000000
    if [ -e "$FIC" ]; then
      FILESIZE=$(/usr/bin/stat -c%s "$FIC")
    else
      debug_log "FIC=$FIC doesn't exist after tar"
      FILESIZE=0
    fi
    #echo_log "res=${RES}"
    splunkconf_checkspace;
    if [ $RES -eq 0 ]; then
        echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC durationms=${DURATION} size=${FILESIZE} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} ${MESS1}"; 
        #echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC durationms=${DURATION} durationns=${DURATIONNS} size=${FILESIZE} ${MESS1}"; 
    else
        fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC durationms=${DURATION} size=${FILESIZE} reason=tar${RES} minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} ${MESS1}" 
    fi
}

function do_remote_copy() {
  FIC=$LFIC
  if [ -e "$FIC" ]; then
    FILESIZE=$(/usr/bin/stat -c%s "$FIC")
  else
    debug_log "FIC=$FIC doesn't exist !"
    FILESIZE=0
  fi
  START=$(($(date +%s%N)));
  if [ "${LFIC}" == "disabled" ]; then
    # local disable case
    echo_log "action=backup type=${TYPE} object=${OBJECT} result=disabled" 
    #debug_log "not doing remote $OBJECT as no local version present MODE=$MODE"
  elif [ $DOREMOTEBACKUP -eq 0 ]; then
    # local ran but remote is disabled
    DURATION=0
    echo_log "action=backup type=${TYPE} object=${OBJECT} result=disabled src=${LFIC} dest=${RFIC} durationms=${DURATION} size=${FILESIZE}" 
  elif [ "${LFIC}" != "disabled" ] && [ "${OBJECT}" == "kvdump" ] && [ "${kvdump_done}" == "0" ]; then
      # we have initiated kvdump but it took so long we never had a complete message so we cant copy as it could be incomplete
      # we want to log here so it appear in dashboard and alerts
      DURATION=0
      fail_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC} durationms=${DURATION} size=${FILESIZE} kvdump may be incomplete, not copying to remote" 
  #elif [ "${LFIC}" != "disabled" ]; then
  else
    if (( REMOTETECHNO == 3 )); then
      debug_log "doing remote copy (rcp) with ${CPCMD} ${OPTION} ${LFIC} ${RCPREMOTEUSER}@${RCPHOST}:${RFIC}"
      ${CPCMD} ${OPTION} ${LFIC} ${RCPREMOTEUSER}@${RCPHOST}:${RFIC}
    elif (( REMOTETECHNO == 4 )); then
      debug_log "doing remote copy (rsync) with ${CPCMD} \"${OPTION}\" ${LOCALSYNCDIR} ${RSYNCREMOTEUSER}@${RSYNCHOST}:${REMOTERSYNCDIR} "
      ${CPCMD} "${OPTION}" ${LOCALSYNCDIR} ${RSYNCREMOTEUSER}@${RSYNCHOST}:${REMOTERSYNCDIR}
      if (( RSYNCAUTORESTORE == 1 )); then
        debug_log "INFO: launching rsync autorestore with $OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-restorerebackup.sh ${TYPE}restore ${RFIC}"
        RESAUTORESTORE=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-restorerebackup.sh ${TYPE}restore ${RFIC}`
      else 
        debug_log "autorestore via rsync disabled by config"
      fi
    elif [ ${AWSCOPYMODE} = "1" ] || [ ${AWSCOPYMODE} = "1" ]; then
      debug_log "doing remote copy with ${CPCMD} ${LFIC} ${CPCMD2} ${SRFIC} ${OPTION}"
      # Attention , we do tags at the same time so if iam are incorrectly set the whole put is going to fail
      # This is why we default now to do it in 2 steps
      ${CPCMD} ${LFIC} ${CPCMD2} ${SRFIC} ${OPTION}
    else
      debug_log "doing remote copy with ${CPCMD} ${LFIC} ${CPCMD2} ${RFIC} ${OPTION}"
      ${CPCMD} ${LFIC} ${CPCMD2} ${RFIC} ${OPTION}
    fi
    RES=$?
    END=$(($(date +%s%N)));
    #let DURATIONNS=(END-START)
    let DURATION=(END-START)/1000000
    if [ $RES -eq 0 ]; then
      echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC} durationms=${DURATION} size=${FILESIZE} ${S3ENDPOINTLOGMESSAGE}" 
      if [[ "cloud_type" -eq 1 ]]; then
        # AWS
        if [ "${REMOTEOBJECTSTORETAGS3}" = "1" ]; then
          debug_log "setting tag via aws ${S3ENDPOINTOPTION} s3api put-object-tagging --bucket ${s3backupbucket} --key ${SRFIC} --tagging ${S3TAGS} "
          aws ${S3ENDPOINTOPTION}  s3api put-object-tagging --bucket ${s3backupbucket} --key ${SRFIC} --tagging ${S3TAGS}
          RES=$?
          if [ $RES -eq 0 ]; then
            echo_log "action=tag type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC} ${S3ENDPOINTLOGMESSAGE}" 
          else
            echo_log "action=tag type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC} ${S3ENDPOINTLOGMESSAGE} Please check IAM for s3:PutObjectTagging" 
          fi
        else
          debug_log "tagging disabled by config"
        fi
      fi
    else
      fail_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC} durationms=${DURATION} size=${FILESIZE}"
    fi
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

###### start

########  initialization for logging ##############
# %u is day of week , we may use this later for custom purge logic
TODAY=`date '+%Y%m%d-%H%M%Z_%u'`;
ID=`date '+%s'`;

#######  ROOT CHECK  #####################
debug_log "checking that we were not launched by root for security reasons"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
   fail_log "Exiting ! This script must be run as splunk user, not root !" 
   exit 1
fi
 

# ARGUMENT CHECK
if [ $# -eq 1 ]; then
  debug_log "Your command line contains $# argument"
  MODE=$1 
elif [ $# -gt 1 ]; then
  warn_log "Your command line contains too many ($#) arguments. Ignoring the extra data"
  MODE=$1
else
  debug_log "No arguments given, running with traditional mode and doing all the backups as stated in conf"
  MODE="0"
fi
case $MODE in
  "0"|"etc"|"state"|"kvauto"|"kvdump"|"kvstore"|"scripts"|"init") debug_log "argument valid" ;;
  *) fail_log "argument $MODE is NOT a valid value, please fix"; exit 1;;
esac
INIT=0
if [ "${MODE}" == "init" ]; then
  # we set mode 0 to have all backups run and also set init to 1
  debug_log "running in init mode, setting up lock to prevent concurrent backup at init"
  MODE="0"
  INIT=1
  `touch ${SPLUNK_HOME}/var/run/splunkconf-init.lock`
fi
debug_log "splunkconf-backup running with MODE=${MODE} and INIT=${INIT}"

####### TEMPO DELAY ############################
if [ "$INIT" == "1" ]; then
  debug_log "no delay as we are in init mode and delay was already part of splunkconf restore"
else
  # addin a random sleep to reduce backup concurrency + a potential conflict when we run at the limit in term of size (one backup type could eat the space before purge run)
  sleep $((1 + RANDOM % 30))
fi

# initialization
ERROR=0
ERROR_MESS=""

# what to use between cp argument , usuaully empty except fro s3api
CPCMD2=""

# include VARs
APPDIR=`pwd`
debug_log "app=splunkconf-backup result=running SPLUNK_HOME=$SPLUNK_HOME splunkconfappdir=${APPDIR} loading splukconf-backup.conf file"
if [[ -f "./default/splunkconf-backup.conf" ]]; then
  . ./default/splunkconf-backup.conf
  debug_log "INFO: splunkconf-backup.conf default succesfully included"
else
  debug_log "INFO: splunkconf-backup.conf default  not found or not readable. Using defaults from script "
fi

if [[ -f "./local/splunkconf-backup.conf" ]]; then
  . ./local/splunkconf-backup.conf
  debug_log "INFO: splunkconf-backup.conf local succesfully included"
else
  debug_log "INFO: splunkconf-backup.conf local not present, using only default"   
fi 
# take over over default and local
if [[ -f "${SPLUNK_HOME}/system/local/splunkconf-backup.conf" ]]; then
  . ${SPLUNK_HOME}/system/local/splunkconf-backup.conf && (echo_log "INFO: splunkconf-backup.conf system local succesfully included") 
else
  debug_log "INFO: splunkconf-backup.conf in system/local not present, no need to include it"
fi

regclass="^[A-Z_]+$"
if [[ "${REMOTES3STORAGECLASS}" = "auto" ]]; then
  REMOTES3STORAGECLASS="STANDARD_IA"
elif [[ "${REMOTES3STORAGECLASS}" =~ $regclass ]]; then
  debug_log "REMOTES3STORAGECLASS=$REMOTES3STORAGECLASS form ok"
else
  warn_log "invalid form  REMOTES3STORAGECLASS=$REMOTES3STORAGECLASS, using default value STANDARD_IA"
  REMOTES3STORAGECLASS="STANDARD_IA"
fi
if [[ "${REMOTES3STORAGECLASSHOURLY}" = "auto" ]]; then
  REMOTES3STORAGECLASSHOURLY="STANDARD"
elif [[ "${REMOTES3STORAGECLASSHOURLY}" =~ $regclass ]]; then
  debug_log "REMOTES3STORAGECLASSHOURLY={$REMOTES3STORAGECLASSHOURLY} form ok"
else
  warn_log "invalid form  REMOTES3STORAGECLASSHOURLY=${REMOTES3STORAGECLASSHOURLY}, using default value STANDARD"
  REMOTES3STORAGECLASSHOURLY="STANDARD"
fi
if [[ "${REMOTES3STORAGECLASSDAILY}" = "auto" ]]; then
  REMOTES3STORAGECLASSDAILY="STANDARD_IA"
elif [[ "${REMOTES3STORAGECLASSDAILY}" =~ $regclass ]]; then
  debug_log "REMOTES3STORAGECLASSDAILY={$REMOTES3STORAGECLASSDAILY} form ok"
else
  warn_log "invalid form  REMOTES3STORAGECLASSDAYLY=${REMOTES3STORAGECLASSDAILY}, using default value STANDARD_IA"
  REMOTES3STORAGECLASSDAILY="STANDARD_IA"
fi
if [[ "${REMOTES3STORAGECLASSWEEKLY}" = "auto" ]]; then
  REMOTES3STORAGECLASSWEEKLY="STANDARD_IA"
elif [[ "${REMOTES3STORAGECLASSWEEKLY}" =~ $regclass ]]; then
  debug_log "REMOTES3STORAGECLASSWEEKLY={$REMOTES3STORAGECLASSWEEKLY} form ok"
else
  warn_log "invalid form  REMOTES3STORAGECLASSWEEKLY=${REMOTES3STORAGECLASSWEEKLY}, using default value STANDARD_IA"
  REMOTES3STORAGECLASSWEEKLY="STANDARD_IA"
fi
if [[ "${REMOTES3STORAGECLASSMONTHLY}" = "auto" ]]; then
  REMOTES3STORAGECLASSMONTHLY="STANDARD_IA"
elif [[ "${REMOTES3STORAGECLASSMONTHLY}" =~ $regclass ]]; then
  debug_log "REMOTES3STORAGECLASSMONTHLY={$REMOTES3STORAGECLASSMONTHLY} form ok"
else
  warn_log "invalid form  REMOTES3STORAGECLASSMONTHLY=${REMOTES3STORAGECLASSMONTHLY}, using default value STANDARD_IA"
  REMOTES3STORAGECLASSMONTHLY="STANDARD_IA"
fi




check_cloud
debug_log "cloud_type=$cloud_type"

check_compress

# we get most var dynamically from ec2 tags associated to instance

# getting tokens and writting to /etc/instance-tags

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
    if grep -qi splunkinstanceType $INSTANCEFILE
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
  splunkorg=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkorg`
  splunkdnszone=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszone`
  splunkdnszoneid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszoneid`
  numericprojectid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/numeric-project-id`
  projectid=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/project-id`
  splunkawsdnszone=`curl -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkawsdnszone`
  
else
  warn_log "aws cloud tag detection disabled (missing commands)"
fi

if [ -e "$INSTANCEFILE" ]; then
  chmod 644 $INSTANCEFILE
  # including the tags for use in this script
  . $INSTANCEFILE
  # note : if the tag detection failed , file may be empty -> we are still checking after
fi
if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then 
    warn_log "WARNING : tags not set via $INSTANCEFILE, trying fallback to /etc version"
    INSTANCEFILE="/etc/instance-tags"
    if [ -e "$INSTANCEFILE" ]; then
      # including the tags for use in this script
      . $INSTANCEFILE
    else
      warn_log "WARNING : no instance tags file at $INSTANCEFILE"
    fi
  fi
fi


if [ -z ${splunks3endpointurl+x} ]; then 
  debug_log "tag splunks3endpointurl, using value ${REMOTES3ENDPOINTURL} from configuration files"
else
  REMOTES3ENDPOINTURL=${splunks3endpointurl}
  debug_log "setting custom endpoint url via tags. This is usually not needed as AWS will figure it out unless for automated testing purpose"
fi

# this regex wont work with inline bash regex as it doesnt support pcre, this is why we need to call grep to do it
regclass="^http[s]{0,1}\:\/\/[a-zA-Z0-9_\-\.\/]+$"
if [[ "${REMOTES3ENDPOINTURL}" = "auto" ]]; then
  S3ENDPOINTOPTION=""
  S3ENDPOINTLOGMESSAGE=""
  debug_log "REMOTES3ENDPOINTURL=auto, not adding option"
#elif [[ "${REMOTES3ENDPOINTURL}" =~ $regclass ]]; then
elif [ $(grep -cP $regclass <<< "${REMOTES3ENDPOINTURL}") -gt 0 ]; then
  S3ENDPOINTOPTION=" --endpoint-url ${REMOTES3ENDPOINTURL} "
  S3ENDPOINTLOGMESSAGE=" endpoint-url=\"${REMOTES3ENDPOINTURL}\" "
  debug_log "will add  ${S3ENDPOINTOPTION} to s3 commands"
else
  warn_log "invalid form for endpoint url, please use http(s)://my_endpoint, ignoring option  "
  S3ENDPOINTOPTION=""
  S3ENDPOINTLOGMESSAGE=""
fi

if [ -z ${splunkrsyncautorestore+x} ]; then 
  debug_log "splunkrsyncautorestore tag not set, using value from conf file rsyncautorestore=$(rsyncautorestore}"
else
  rsyncautorestore=${splunkrsyncautorestore}
  debug_log "splunkrsyncautorestore tag set, rsyncautorestore=$(rsyncautorestore}"
fi
  

if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then 
    if [ "${REMOTEBACKUPDIR}" = "s3://pleaseconfigurenstancetagsorsetdirectlythes3bucketforbackupshere-splunks3splunkbackup/splunkconf-backup" ] && [ "${REMOTEOBJECTSTOREBUCKET}" = "auto" ]; then 
      ## there is no tag from instance metadata so we are not in a cloud instance or that instance hasnt been configured for doing remote backups
      # there is also the REMOTEOBJECTSTOREBUCKET with default value auto
      DOREMOTEBACKUP=0
      warn_log "name=splunks3backupbucket  src=instancetags result=unset remotebackup=disabled "; 
    elif  [ "${REMOTEOBJECTSTOREBUCKET}" != "auto" ]; then 
      # REMOTEOBJECTSTOREBUCKET is set lets use this
       s3backupbucket=$REMOTEOBJECTSTOREBUCKET
      if [[ "cloud_type" -eq 2 ]]; then
        # GCP
        debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
        # we already have the scheme in var for gcp
        REMOTEBACKUPDIR="${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
        #REMOTEBACKUPDIR="${s3backupbucket}/splunkconf-backup"
        debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
      else
        debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
        REMOTEBACKUPDIR="s3://${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
        #REMOTEBACKUPDIR="s3://${s3backupbucket}/splunkconf-backup"
        debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
      fi
    else
      # on prem with remote backup configured or static configuration in cloud 
      debug_log "name=remotebackup src=remotebackup result=configured"
    fi
  else 
    if (( REMOTETECHNO == 3 )); then 
      debug_log "remote techno=3 and running in cloud , not using tags"
    elif (( REMOTETECHNO == 4 )); then 
      debug_log "remote techno=4 and running in cloud , not using tags"
    elif [[ "cloud_type" -eq 2 ]]; then
      # GCP
      debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
      # we already have the scheme in var for gcp
      REMOTEBACKUPDIR="${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
      #REMOTEBACKUPDIR="${s3backupbucket}/splunkconf-backup"
      debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
    else
      debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
      REMOTEBACKUPDIR="s3://${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
      #REMOTEBACKUPDIR="s3://${s3backupbucket}/splunkconf-backup"
      debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
    fi
  fi
else
  s3backupbucket=$splunks3backupbucket
  if (( REMOTETECHNO == 3 )); then 
      debug_log "remote techno=3 and running in cloud , not using tags"
  elif (( REMOTETECHNO == 4 )); then 
      debug_log "remote techno=4 , not using tags"
  elif [[ "cloud_type" -eq 2 ]]; then
    # GCP
    debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=true";
      # we already have the scheme in var for gcp
    REMOTEBACKUPDIR="${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
    #REMOTEBACKUPDIR="${s3backupbucket}/splunkconf-backup"
    debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
  else
    debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=true";
    REMOTEBACKUPDIR="s3://${s3backupbucket}/${REMOTEOBJECTSTOREPREFIX}"
    #REMOTEBACKUPDIR="s3://${s3backupbucket}/splunkconf-backup"
    debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
  fi
fi

if (( REMOTETECHNO == 4 )); then 
  debug_log "remote techno=4 (rsync) setting REMOTEBACKUPDIR to empty as we rsync to same path"
  REMOTEBACKUPDIR=""
  #if [ ${REMOTETECHNO} -eq 4 ]; then
    OPTION=" ssh -oConnectTimeout=30 -oServerAliveInterval=60 -oBatchMode=yes -oStrictHostKeyChecking=accept-new";
    if (( RSYNCDISABLEREMOTE == 1 )); then
      debug_log "INFO: Disabling remote splunk (just in case as should be already stopped to prevent a clone conflict  situation"
      RESSTOP=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} "${SPLUNK_HOME}/bin/splunk status && ${SPLUNK_HOME}/bin/splunk stop"`
      RESSTATUS=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} "${SPLUNK_HOME}/bin/splunk status"`
      echo_log "mode=init remotestopstatus=$RESSTOP remotestatus=$RESSTATUS"
    fi
    if ((  RSYNCREMOTEDELETE == 2 )); then
      debug_log "INFO: launching remote splunkconf-purgebackup.sh"
      RESPURGE=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-purgebackup.sh`
    fi
  #fi
fi

if [[ -f "${APPDIR}/lookups/splunkconf-exclude.csv" ]]; then
  TAREXCLUDEFILE="${APPDIR}/lookups/splunkconf-exclude.csv"
else
  TAREXCLUDEFILE="/dev/null"
  warn_log "OOOPS ! we cant find splunkconf-exclude.csv in lookups directory ${APPDIR}/lookups/splunkconf-exclude.csv ! This is not expected , please correct" 
fi


if [ -z ${BACKUP+x} ]; then fail_log "BACKUP not defined in ENVSPL file. Not doing backup as requested!"; exit 0; else debug_log "BACKUP=${BACKUP}"; fi
if [ -z ${LOCALBACKUPDIR+x} ]; then echo_log "LOCALBACKUPDIR not defined in ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "LOCALBACKUPDIR=${LOCALBACKUPDIR}"; fi
if [ -z ${SPLUNK_HOME+x} ]; then fail_log "SPLUNK_HOME not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "SPLUNK_HOME=${SPLUNK_HOME}"; fi
if [ -z ${SPLUNK_DB+x} ]; then fail_log "SPLUNK_DB not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "SPLUNK_DB=${SPLUNK_DB}"; fi

EXTENSIONKV="gz"

HOST=`hostname`;

#SERVERNAME=`grep guid ${SPLUNK_HOME}/etc/instance.cfg`;
# warning may contain spaces, line with comments ...
SERVERNAME=`grep ^serverName ${SPLUNK_HOME}/etc/system/local/server.conf  | awk '{print $3}'`
# disabled : require logged in user...
#SERVERNAME=`${SPLUNK_HOME}/bin/splunk show servername  | awk '{print $3}'`
#splunk show servername
 
debug_log "src detection  : splunkinstanceType=$splunkinstanceType,${#splunkinstanceType}, SERVERNAME=$SERVERNAME, ${#SERVERNAME},  HOST=$HOST"
if [ ${#splunkinstanceType} -ge 2 ]; then 
  INSTANCE=$splunkinstanceType
  debug_log "using splunkinstanceType tag for instance, instance=${INSTANCE} src=splunkinstanceType"
elif [ ${#SERVERNAME} -ge 2 ]; then 
  INSTANCE=$SERVERNAME
  debug_log "using servername for instance, instance=${INSTANCE} src=servername"
else 
  INSTANCE=$HOST
  debug_log "ATTENTION : servername missing, falllback to using host for instance, instance=${INSTANCE} src=host"
fi
# servername is more reliable in dynamic env like AWS 
#INSTANCE=$SERVERNAME

if [ "$INIT" == "1" ]; then
  debug_log "INIT mode"
  #echo_log "INIT mode , removing lock file so other backup process may run"
  #  `rm ${SPLUNK_HOME}/var/run/splunkconf-init.lock`
else
  debug_log "not in init mode, checking for init lock"
  lockname="init"
  lockmindelay=50
  lockmessage="splunkconf-backup is currently running in init mode, stopping backup creation to avoid conflic"
  checklock;
fi
# FIXME : opti : relax check to only exit if global or kvdump/kvstore mode
debug_log "checking for a ongoing kvdump restore"
lockname="kvrestore"
lockmindelay=120
lockmessage="splunkconf-restore is currently running a kvdump, stopping backup creation to avoid creating a incomplete backup"
checklock;

# creating dir

# warning : if this fail because splunk can't create it, then root should create it and give it to splunk"
# this is context dependant

mkdir -p $LOCALBACKUPDIR

if [ ! -d "$LOCALBACKUPDIR" ]; then
  fail_log "backupdir=${LOCALBACKUPDIR} type=local object=creation result=failure dir couldn't be created by script. Please check and fix permissions or create it and allow splunk to write into it";
  ERROR=1
  ERROR_MESSAGE="backupdircreateerror"
  exit 1;
fi

if [ ! -w $LOCALBACKUPDIR ] ; then 
  fail_log "backupdir=${LOCALBACKUPDIR} type=local object=write result=failure dir isn't writable by splunk !. Please check and fix permissions and allow splunk to write into it";
  ERROR=1
  ERROR_MESSAGE="backupdirmissingwritepermissionerror"
  exit 1;
fi


############# START HERE DO DO THE BACKUPS   ####################3
TYPE="local"

# etc
etc_done=0
LFICETC="disabled";
OBJECT="etc"
if [ "$MODE" == "0" ] || [ "$MODE" == "etc" ]; then 
  cd /
  # building name depending on options
  if [ ${BACKUPTYPE} -eq 2 ]; then
    if [ ${LOCALTYPE} -eq 2 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-full-${INSTANCE}.tar.${EXTENSION}";
	MESS1="backuptype=etcfullinstanceoverwrite ";
    elif [ ${LOCALTYPE} -eq 3 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-full.tar.${EXTENSION}";
	MESS1="backuptype=etcfullnoinstanceoverwrite ";
    else
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-full-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
	MESS1="backuptype=etcfullinstanceversion ";
    fi
  else
    if [ ${LOCALTYPE} -eq 2 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}.tar.${EXTENSION}";
	MESS1="backuptype=etctargetedinstanceoverwrite ";
    elif [ ${LOCALTYPE} -eq 3 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted.tar.${EXTENSION}";
	MESS1="backuptype=etctargetednoinstanceoverwrite ";
    else
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
	MESS1="backuptype=etctargetedinstanceversion ";
    fi
  fi
  splunkconf_purgebackup;
  splunkconf_checkspace;
  if [ $ERROR -ne 0 ]; then
    fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}" 
  elif [ ${BACKUPTYPE} -eq 2 ]; then
    debug_log "running tar for etc full backup";
    if [ "${TARMODE}" = "abs" ]; then
        FILELIST="${SPLUNK_HOME}/etc"
    else
        FILELIST="./etc"
    fi
    #tar -zcf ${FIC}  ${FILELIST} && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
    do_backup_tar;
    etc_done=1
    LFICETC=$FIC;
  else
    #debug_log "running tar for etc targeted backup
    # dump exlusion for collection app that store temp huge files in etc instead of a proper dir under var
    if [ "${TARMODE}" = "abs" ]; then
        FILELIST2="${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/deployment-apps ${SPLUNK_HOME}/etc/master-apps ${SPLUNK_HOME}/etc/manager-apps ${SPLUNK_HOME}/etc/shcluster ${SPLUNK_HOME}/etc/passwd ${SPLUNK_HOME}/etc/system/local ${SPLUNK_HOME}/etc/auth ${SPLUNK_HOME}/etc/openldap/ldap.conf ${SPLUNK_HOME}/etc/users ${SPLUNK_HOME}/etc/splunk-launch.conf ${SPLUNK_HOME}/etc/instance.cfg ${SPLUNK_HOME}/etc/.ui_login ${SPLUNK_HOME}/etc/licenses ${SPLUNK_HOME}/etc/*.cfg ${SPLUNK_HOME}/etc/disabled-apps"
    else
        FILELIST2="./etc/apps ./etc/deployment-apps ./etc/master-apps ./etc/manager-apps ./etc/shcluster ./etc/passwd ./etc/system/local ./etc/auth ./etc/openldap/ldap.conf ./etc/users ./etc/splunk-launch.conf ./etc/instance.cfg ./etc/.ui_login ./etc/licenses ./etc/*.cfg ./etc/disabled-apps"
    fi
    FILELIST=""
    for file in $FILELIST2;
    do
      if [ -e "${backuptardir}/${file}" ]; then
        FILELIST="$FILELIST ${file}"
      fi
    done
    #tar --exclude-from=${TAREXCLUDEFILE} --exclude '*/dump' -zcf ${FIC} ${FILELIST} && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
    do_backup_tar;
    etc_done=1
    LFICETC=$FIC;
  fi
# if mode explicit etc or all
fi

scripts_done=0
LFICSCRIPT="disabled";
OBJECT="scripts"
if [ "$MODE" == "0" ] || [ "$MODE" == "scripts" ]; then 
  FIC="disabled"
  #debug_log "start to backup scripts"; 
  if [ ${LOCALTYPE} -eq 2 ]; then
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}.tar.${EXTENSION}";
    ESS1="backuptype=scriptstargetedinstanceoverwrite ";
  elif [ ${LOCALTYPE} -eq 3 ]; then
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}scripts.tar.${EXTENSION}";
    MESS1="backuptype=scriptstargetednoinstanceoverwrite  ";
  else
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
    MESS1="backuptype=scriptstargetedinstanceversion ";
  fi
  splunkconf_purgebackup;
  splunkconf_checkspace;
  if [ -z ${BACKUPSCRIPTS+x} ] || [ $BACKUPSCRIPTS -eq 0 ]; then
    # we echo here to have it appear in logs as it will allow to identify disabled versus missing case
    echo_log "action=backup type=$TYPE object=${OBJECT} result=disabled dest=$FIC reason=disabled ${MESS1}" 
  elif [ $ERROR -ne 0 ]; then
    fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
  else 
    #debug_log "doing backup scripts via tar";
    FILELIST=${SCRIPTDIR}
    FILELIST2=""
    for i in $FILELIST;
    do
      #debug_log "mode=$MODE, i=$i"
      if [ -e "${backuptardir}/$i" ]; then
        debug_log "fileverif : $i exist"
        # Assuming here it contains dir
        LIS=`ls ${backuptardir}/$i|wc -l`
        if (( $LIS > 0 )); then 
          debug_log "fileverif : $i exist and not empty"
          FILELIST2="${STATELIST2} $i"
        else
          debug_log "fileverif : $i exist and  empty, not adding it"
        fi
     else
        debug_log "fileverif : $i NOT exist"
     fi
    done
    debug_log "FILELIST=${STATELIST} FILELIST2=${FILELIST2}"
    if [ ! -z "${FILELIST2}" ]; then

      #tar -zcf ${FIC}  ${FILELIST} && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
      do_backup_tar;
      scripts_done=1
      LFICSCRIPT=$FIC;
    else
      echo_log "action=backup type=$TYPE object=$OBJECT result=autodisabledempty"
    fi
  fi
  # debug
  #echo "backup dir contains (tail)"
  #ls -ltr ${LOCALBACKUPDIR}| tail 
  # if mode explicit scripts or all
fi


kvstore_done=0
LFICKVSTORE="disabled"
kvdump_done=0
LFICKVDUMP="disabled"
OBJECT="kvstore"
if [ "$MODE" == "0" ] || [ "$MODE" == "kvdump" ] || [ "$MODE" == "kvstore" ] || [ "$MODE" == "kvauto" ]; then 
  debug_log "object=kvstore  action=start"
  FIC="disabled"
  isforwarder=`${SPLUNK_HOME}/bin/splunk version | tail -1 | grep -i forwarder`;
  if [ -z ${isforwarder+x} ] || [[ "${isforwarder}" =~ "orwarder" ]];  then
    echo_log "action=backup type=$TYPE object=${OBJECT} result=disabled reason=ufdisabled"; 
  elif [ -z ${BACKUPKV+x} ] || [ $BACKUPKV -eq 0 ]; then
    echo_log "action=backup type=$TYPE object=${OBJECT} result=disabled reason=disabledbyconfiguration"; 
  else
    # we do a tail to get the last line as sometimes there can be warning on first lines so the version is always last line
    version=`${SPLUNK_HOME}/bin/splunk version | tail -1 | cut -d ' ' -f 2`;
    if [[ $version =~ ^([^.]+\.[^.]+)\. ]]; then
      ver=${BASH_REMATCH[1]}
      debug_log "splunkversion=$ver"
    else
      fail_log "splunkversion : unable to parse string $version"
    fi
    minimalversion=7.0
    kvbackupmode=taronline
    MESSVER="currentversion=$ver, minimalversionover=${minimalversion}";
    btoolkvstore=`${SPLUNK_HOME}/bin/splunk btool server list kvstore | grep disabled`;
    splunkconf_purgebackup;
    splunkconf_checkspace;
    if [[ $btoolkvstore =~ "true" ]] || [[ $btoolkvstore =~ "1" ]]; then
      echo_log "action=backup type=$TYPE object=${OBJECT} result=disabled reason=kvstoredisabledonsplunkbyconfig";
    elif [ $ERROR -ne 0 ]; then
      fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
    # bc not present on some os changing if (( $(echo "$ver >= $minimalversion" |bc -l) )); then
    #if [[ $ver \> $minimalversion ]]  && [[ "$MODE" == "0"  || "$MODE" == "kvdump" || "$MODE" == "kvauto" ]]; then
    elif [ $ver \> $minimalversion ]  && ([[ "$MODE" == "0" ]] || [[ "$MODE" == "kvdump" ]] || [[ "$MODE" == "kvauto" ]]); then
      kvbackupmode=kvdump
      #echo_log "splunk version 7.1+ detected : using online kvstore backup "
      # important : this need passauth correctly set or the script could block !
      # This is avoiding to hardcode password or token in the app
      read sessionkey
      # get the management uri that match the current instance (we cant assume it is always 8089)
      #disabled we dont want to log this for obvious security reasons debug: echo "session key is $sessionkey"
      #MGMTURL=`${SPLUNK_HOME}/bin/splunk btool web list settings --debug | grep mgmtHostPort | grep -v \#| cut -d ' ' -f 4|tail -1`
      MGMTURL=`${SPLUNK_HOME}/bin/splunk btool web list settings --debug | grep mgmtHostPort | grep -v \# | sed -r 's/.*=\s*([0-9\.:]+)/\1/' |tail -1`
 
      # check pre backup
      RES=`curl --silent -k https://${MGMTURL}/services/kvstore/status  --header "Authorization: Splunk ${sessionkey}" `
      debug_log "full kvstore status RES=$RES"
      RES=`curl --silent -k https://${MGMTURL}/services/kvstore/status  --header "Authorization: Splunk ${sessionkey}" | grep backupRestoreStatus | grep -i Ready`
      debug_log "kvstore status before launching backup RES=$RES"
      #debug_log "COUNTER=$COUNTER $MESSVER $MESS1 type=$TYPE object=${kvbackupmode} action=backup result=running "

      KVARCHIVE="backupconfsplunk-kvdump-${TODAY}"
      MESS1="MGMTURL=${MGMTURL} KVARCHIVE=${KVARCHIVE}";
      START=$(($(date +%s%N)));
      


      RES=`curl --silent -k https://${MGMTURL}/services/kvstore/backup/create -X post --header "Authorization: Splunk ${sessionkey}" -d"archiveName=${KVARCHIVE}"`
      #echo_log "KVDUMP CREATE RES=$RES"
      COUNTER=50
      RES=""
      # wait a bit (up to 20*10= 200s) for backup to complete, especially for big kvstore/busy env (io)
      # increase here if needed (ie take more time !)
      until [[  $COUNTER -lt 1 || -n "$RES"  ]]; do
        RES=`curl --silent -k https://${MGMTURL}/services/kvstore/status  --header "Authorization: Splunk ${sessionkey}" | grep backupRestoreStatus | grep -i Ready`
        #echo_log "RES=$RES"
        debug_log "COUNTER=$COUNTER $MESSVER $MESS1 type=$TYPE object=${kvbackupmode} action=backup result=running "
        let COUNTER-=1
        sleep 10
      done
      #echo_log "RES=$RES"
      END=$(($(date +%s%N)));
      #let DURATIONNS=(END-START)
      let DURATION=(END-START)/1000000
      FIC="${SPLUNK_DB}/kvstorebackup/${KVARCHIVE}.tar.${EXTENSIONKV}"
      LFICKVDUMP=$FIC
      if [ -e "$FIC" ]; then
        FILESIZE=$(/usr/bin/stat -c%s "$FIC")
      else
        debug_log "FIC=$FIC doesnt exist after kvdump"
        FILESIZE=0
      fi
      if [[ -z "$RES" ]];  then
	warn_log "COUNTER=$COUNTER $MESSVER $MESS1 type=$TYPE object=$kvbackupmode result=failure dest=${LFICKVDUMP} durationms=${DURATION} size=${FILESIZE}  ATTENTION : we didnt get ready status ! Either backup kvstore (kvdump) has failed or takes too long"
	kvdump_done="-1"
      else
	kvdump_done="1"
	echo_log "COUNTER=$COUNTER $MESSVER $MESS1 action=backup type=$TYPE object=$kvbackupmode result=success dest=${LFICKVDUMP} durationms=${DURATION} size=${FILESIZE}  kvstore online (kvdump) backup complete"
      fi
    elif [[ "$MODE" == "0" ]] || [[ "$MODE" == "kvstore" ]] || [[ "$MODE" == "kvauto" ]]; then
      if [[ "$MODE" == "0" ]] || [[ "$MODE" == "kvauto" ]]; then
        echo_log "object=kvdump action=unsupportedversion splunk_version not yet 7.1, cant use online kvstore backup, trying kvstore tar instead"
      else 
        echo_log "object=kvstore doing kvstore backup as especially requested even if 7.1"
      fi  
      kvbackupmode=taronline
      # WARNING : splunk should be stopped for the backup to be consistent
      if [ -z ${RESTARTFORKVBACKUP+x} ]; then 
        debug_log "doing kvstore backup without restarting"; 
      else
        kvbackupmode=taroffline
        debug_log "stopping splunk service on $INSTANCE"
        ${SPLUNK_HOME}/bin/splunk stop;
        debug_log "waiting 10s after stopping splunk service"
        sleep 10;
      fi
      debug_log "doing backup kvstore via tar";
      if [ ${LOCALTYPE} -eq 2 ]; then
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}.tar.${EXTENSION}";
        MESS1="backuptype=kvstoreinstanceoverwrite ";
        debug_log "backup for kvstore no date with instance to $FIC";
      elif [ ${LOCALTYPE} -eq 3 ]; then
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}kvstore.tar.${EXTENSION}";
        MESS1="backuptype=kvstorenoinstanceoverwrite ";
        debug_log "backup for kvstore no date no instance to $FIC";
      else
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        MESS1="backuptype=kvstoreinstanceversion ";
        debug_log "backup for kvstore with instance and date to $FIC";
      fi
      CONTINUE=1;
      KVBOK=0;
      KVBKO=0;
      KVBKOMAX=10;
      kvstore_done="1"
      while [ ${CONTINUE} -eq 1 ]
      do
        #echo_log "running tar for kvstore"
        FILELIST=${KVDBPATH}

        echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC durationms=${DURATION} size=${FILESIZE} ${MESS1}";

        START=$(($(date +%s%N)));
        tar -I ${COMPRESS} -C${backuptardir} -cf ${FIC}  ${FILELIST}
        RES=$?
        #echo_log "res=${RES}"
        END=$(($(date +%s%N)));
        #let DURATIONNS=(END-START)
        let DURATION=(END-START)/1000000
        if [ -e "$FIC" ]; then
           FILESIZE=$(/usr/bin/stat -c%s "$FIC")
        else
           debug_log "FIC=$FIC doesn't exist after tar"
           FILESIZE=0
        fi
        if [ $RES -eq 0 ]; then
           echo_log "${MESS1} action=backup type=$TYPE object=kvstore result=success dest=$FIC durationms=${DURATION} size=${FILESIZE}";
           KVBOK=1;
           CONTINUE=0;
        else
           warn_log "${MESS1} action=backup type=$TYPE object=kvstore result=retry kotry=${KVBKO} komax=${KVBKOMAX} dest=$FIC  durationms=${DURATION} size=${FILESIZE} local kvstore backup returned error (probably file changed during backup) , please investigate";
           ((KVBKO++))
           CONTINUE=0;
           if [ $KVBKO -lt ${KVBKOMAX} ]; then 
               CONTINUE=1;
           fi
        fi
        debug_log "KVBOK=${KVBOK} , KVBKO=${KVBKO}, CONTINUE=${CONTINUE} "
      done
      if [ $KVBOK -eq 0 ]; then
        fail_log "${MESS1} action=backup type=$TYPE object=kvstore result=failure dest=$FIC kvstore backup tried ${KVBKOMAX} times but kvstore keep changing while backuping,backup may be corrupted !  please try with the option to stop splunk or via online kvdump backup (splunk 7.1+)"
      fi
      if [ -z ${RESTARTFORKVBACKUP+x} ]; then debug_log "done kvstore backup (tar) without restarting"; else
        debug_log "starting splunk service on $INSTANCE"
        ${SPLUNK_HOME}/bin/splunk start;
        debug_log "done kvstore backup(tar) with splunk service restart";
      fi
      LFICKVSTORE=$FIC;
      # end traditional kvstore backup
    else 
      debug_log "action=backup object=kvstore type=$TYPE result=nobackuprequested"
    fi
  fi
  # if mode explicit kvxxx or all
fi


state_done=0
LFICSTATE="disabled"
OBJECT="state"
#debug_log "before state test reached. MODE=${MODE}."
if [ "$MODE" == "0" ] || [ "$MODE" == "state" ]; then
  #debug_log "after state test reached, MODE=$MODE "
  # STATE : scheduler,  MODINPUT,...
  FIC="disabled"
  if [ -z ${BACKUPSTATE+x} ]; then 
    echo_log "action=backup type=$TYPE object=$OBJECT result=disabled"
  else
    debug_log "start to backup state (modinputs , scheduler states, bundle, fishbuckets,....)";
    if [ ${LOCALTYPE} -eq 2 ]; then
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}.tar.${EXTENSION}";
      MESS1="backuptype=stateinstanceoverwrite ";
      debug_log "backup type will be state with instance no date";
    elif [ ${LOCALTYPE} -eq 3 ]; then
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}state.tar.${EXTENSION}";
      MESS1="backuptype=statenoinstanceoverwrite ";
      debug_log "backup type will be state no instance no date";
    else
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
      MESS1="backuptype=stateinstanceversion ";
      debug_log "backup type will be state (date versioned with instance backup mode)";
    fi
    STATELIST2=""
    #debug_log"mode=$MODE, checking state list"
    for i in $STATELIST;
    do
      #debug_log "mode=$MODE, i=$i"
      if [ -e "${backuptardir}/$i" ]; then
        STATELIST2="${STATELIST2} $i"
        debug_log "stateverif : $i exist"
     else
        debug_log "stateverif : $i NOT exist"
     fi
    done
    debug_log "STATELIST=${STATELIST} STATELIST2=${STATELIST2}" 
    if [ ! -z "${STATELIST2}" ]; then 
      splunkconf_purgebackup;
      splunkconf_checkspace;
      if [ $ERROR -ne 0 ]; then
        fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
      else
        #echo_log "doing backup state (modinputs and scheduler state) via tar";
        #result=$(tar -zcf ${FIC}  ${MODINPUTPATH} ${SCHEDULERSTATEPATH} ${STATELIST}  2>&1 | tr -d "\n") && echo_log "${MESS1} action=backup type=local object=state result=success dest=$FIC local state backup succesfull (result=$result)" || warn_log "${MESS1} action=backup type=local object=state result=failure dest=$FIC local state backup returned error , please investigate (modinputpath=${MODINPUTPATH} schedulerpath=${SCHEDULERSTATEPATH}  statelist=${STATELIST} result=$result )"
        FILELIST=${STATELIST2}
        #result=$(tar -zcf ${FIC} ${FILELIST}  2>&1 | tr -d "\n") && echo_log "${MESS1} action=backup type=local object=state result=success dest=$FIC local state backup succesfull (result=$result)" || warn_log "${MESS1} action=backup type=local object=state result=failure dest=$FIC local state backup returned error , please investigate (statelist=${STATELIST} statelist2=${STATELIST2} result=$result )"
        do_backup_tar;
        state_done=1
        LFICSTATE=$FIC;
      fi
    else
      ERROR_MESS="nostatefiles"
      MESS1=""
      fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
    fi
  fi
  # if mode explicit state or all
fi
debug_log "MODE=$MODE, extmode=${extmode} starting remote part"

###############################    REMOTE    #############################################3

# remote techno 1 = nas, 2=S3, 3= scp to nas, 4 = rsync
# remotetype 0=auto, 1=date, 2 = no date, 3= no date, no instance

TYPE="remote"
debug_log "starting remote backup"
  if [ ${REMOTETYPE} -eq 0 ]; then 
    if [ ${REMOTETECHNO} -eq 2 ]; then
      REMOTETYPE=3;
      debug_log "object store remote type with versioning, automatic switching to non date and non instance format";
    elif [ ${REMOTETECHNO} -eq 4 ]; then
      REMOTETYPE=3;
      debug_log "rsync mode, automatic switching to non date and non instance format in order to ease automatic restore";
    else 
      REMOTETYPE=1;
      debug_log "NAS type, automatic switching to date+instance format";
    fi
  else 
    debug_log "remote_type statically set, unchanged, it is set to ${REMOTETYPE}"
  fi
if [ $DOREMOTEBACKUP -eq 1 ]; then
  if [ ${REMOTETECHNO} -eq 1 ]; then 
        #echo_log "running directories check for NAS type on $REMOTEBACKUPDIR"
  	if [ ! -d "$REMOTEBACKUPDIR" ]; then
  		fail_log "remote backup dir  (${REMOTEBACKUPDIR}) not present. Check remote filesystem is mounted, dir created and dir writable by splunk user";
		exit 1;
	fi
	if [ ! -w $REMOTEBACKUPDIR ] ; then
  		fail_log "remote backup dir  (${REMOTEBACKUPDIR}) not writable by splunk. Check remote filesystem is mounted, dir created and dir writable by splunk user";
		exit 1;
	fi
  fi
fi
  if (( REMOTETECHNO == 4 ));then
    debug_log "renotetechno=4 (rsync) not adding instance name to remotebackup dir"
  else
    # now we add the instance name or backup from different instances would collide
    REMOTEBACKUPDIR="${REMOTEBACKUPDIR}/${INSTANCE}"
    REMOTEOBJECTSTOREPREFIX="${REMOTEOBJECTSTOREPREFIX}/${INSTANCE}"
    # first run we are creating that instance dir
  fi

  if [ ${REMOTETECHNO} -eq 1 ]; then 
  # nas
    if [ ! -d "$REMOTEBACKUPDIR" ]; then
      mkdir ${REMOTEBACKUPDIR} && echo_log "creation of instance dir on remote storage succesfull (${REMOTEBACKUPDIR})" || ( fail_log "creation of instance dir on remote storage FAILED ! (${REMOTEBACKUPDIR})";exit 1;)
    else 
      debug_log "REMOTEBACKUPDIR ${REMOTEBACKUPDIR} exist" 
    fi
  elif [ ${REMOTETECHNO} -eq 2 ]; then
    # s3
    debug_log "s3 or gcp"
  elif [ ${REMOTETECHNO} -eq 3 ]; then
    # remote via scp
    debug_log "backup via scp"
    # dir creation remote here FIXME
  elif [ ${REMOTETECHNO} -eq 4 ]; then
    # remote via rsync over ssh
    debug_log "backup via rsync over ssh"
    # no need to for remote dir creation, rsync will create backups dir automatically if not present
  else
    fail_log "cant do remote backup. unknown remotetechno ${REMOTETECHNO}. Please fix configuration settings"
    exit 1
  fi


  cd /
  if [ ${BACKUPTYPE} -eq 2 ]; then
    # full etc mode
    if [ ${REMOTETYPE} -eq 2 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk$-{extmode}etc-full-${INSTANCE}.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk$-{extmode}etc-full-${INSTANCE}.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts-${INSTANCE}.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore-${INSTANCE}.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump-${INSTANCE}.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state-${INSTANCE}.tar.${EXTENSION}";
        debug_log "backup type will be etc full no date";
    elif [ ${REMOTETYPE} -eq 3 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}etc-full.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}etc-full.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state.tar.${EXTENSION}";
        debug_log "backup type will be etc full no date no instance";
    else
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}etc-full-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}etc-full-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        debug_log "backup type will be etc full (date versioned backup mode with instance name)";
    fi
  else
    # targeted mode (default)
    if [ ${REMOTETYPE} -eq 2 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts-${INSTANCE}.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore-${INSTANCE}.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump-${INSTANCE}.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state-${INSTANCE}.tar.${EXTENSION}";
        debug_log "backup type will be etc targeted no date";
    elif [ ${REMOTETYPE} -eq 3 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}etc-targeted.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state.tar.${EXTENSION}";
        debug_log "backup type will be etc targeted no date no instance ";
    else
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}scripts-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}kvstore-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.${EXTENSIONKV}";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-${extmode}state-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICETC="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}etc-targeted-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICSCRIPT="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}scripts-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICKVSTORE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}kvstore-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        SFICKVDUMP="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.${EXTENSIONKV}";
        SFICSTATE="${REMOTEOBJECTSTOREPREFIX}/backupconfsplunk-${extmode}state-${INSTANCE}-${TODAY}.tar.${EXTENSION}";
        debug_log "backup type will be etc targeted (date versioned backup mode)";
    fi
  fi


  CPCMD="echo "
  if [ ${REMOTETECHNO} -eq 1 ]; then 
    CPCMD="cp -p ";
    OPTION="";
  elif [ ${REMOTETECHNO} -eq 2 ]; then
    # azure, see https://docs.microsoft.com/en-us/cli/azure/storage?view=azure-cli-latest#az-storage-copy
    if [[ "cloud_type" -eq 2 ]]; then
     # gcp
      CPCMD="gsutil -q cp";
      OPTION="";
    else 
      # aws
      tagname="frequency"
      # - disable padding with 0
      hournumber=`date +"%-H"`
      # day of week (1..7); 1 is Monday
      weekdaynumber=`date +"%-u"`
      dayofmonthnumber=`date +"%-d"`
      debug_log "hournumber=$hournumber, weekdaynumber=$weekdaynumber, dayofmonthnumber=$dayofmonthnumber"
      # we use different hours to flag backups so if a month start also is a week start, we can keep 2 backups
      # we do not use 2 and 3 as there may be a summer/winter time event
      # also we take a backup during night
      if [ "${dayofmonthnumber}" = "1" ] && [ "${hournumber}" = "04" ]; then
        # first day of month  at 4
        S3TAGS="TagSet=[{Key=${tagname},Value=monthly}]"
        REMOTES3STORAGECLASSCURRENT=${REMOTES3STORAGECLASSMONTHLY}
      elif [ "${weekdaynumber}" = "1" ] && [ "${hournumber}" = "5" ]; then
        # monday at 5
        S3TAGS="TagSet=[{Key=${tagname},Value=weekly}]"
        REMOTES3STORAGECLASSCURRENT=${REMOTES3STORAGECLASSWEEKLY}
      elif [ "${hournumber}" = "6" ]; then
        # every day at 6
        S3TAGS="TagSet=[{Key=${tagname},Value=daily}]"
        REMOTES3STORAGECLASSCURRENT=${REMOTES3STORAGECLASSDAILY}
      else
        S3TAGS="TagSet=[{Key=${tagname},Value=hourly}]"
        REMOTES3STORAGECLASSCURRENT=${REMOTES3STORAGECLASSHOURLY}
      fi
      if [ ${AWSCOPYMODE} = "1" ] || [ ${AWSCOPYMODE} = "1" ]; then
        # we use s3api because it allow to set tags at same time which s3 cp doenst suppport at the moment
        CPCMD="aws ${S3ENDPOINTOPTION} s3api put-object --bucket ${s3backupbucket} --body ";
        CPCMD2="--key "
        # quiet doesnt exist with s3api
        if [ "${REMOTEOBJECTSTORETAGS3}" = "1" ]; then
          OPTION=" --storage-class ${REMOTES3STORAGECLASSCURRENT} --tagging ${S3TAGS}";
        else
          OPTION=" --storage-class ${REMOTES3STORAGECLASSCURRENT}";
        fi
      else
        CPCMD="aws ${S3ENDPOINTOPTION} s3 cp";
        OPTION=" --quiet --storage-class ${REMOTES3STORAGECLASSCURRENT}";
        #OPTION=" --quiet --storage-class STANDARD_IA";
      fi
    fi
# --storage-class STANDARD_IA reduce cost for infrequent access objects such as backups while not decreasing availability/redundancy
  elif [ ${REMOTETECHNO} -eq 3 ]; then
    CPCMD="scp";
# second option depend on recent ssh , instead it is possible to disable via =no or use other mean to accept the key before the script run
    OPTION="-oConnectTimeout=30 -oServerAliveInterval=60 -oBatchMode=yes -oStrictHostKeyChecking=accept-new";
    RESMKDIR=`ssh $OPTION  ${RCPREMOTEUSER}@${RCPHOST} mkdir -p ${REMOTEBACKUPDIR}`
  elif [ ${REMOTETECHNO} -eq 4 ]; then
    OPTION=" ssh -oConnectTimeout=30 -oServerAliveInterval=60 -oBatchMode=yes -oStrictHostKeyChecking=accept-new";
    # second option depend on recent ssh , instead it is possible to disable via =no or use other mean to accept the key before the script run
    # special case for rsync the option will be added just after CPCMD and quoted
    if ((  RSYNCREMOTEDELETE == 1 )); then 
      # we use archive mode, we ask to delete extra file on remote (this is needed to reduce risk of filling remote disk which would prevent syncing backups. It also avoid to have to do a remote purge. It is important to have extra space in rsync mode on both nodes
      CPCMD="rsync -a --delete -e ";
    else
      # do not delete via rsync  (you should have enabled another way of purging remote content of the remote disk could fill up and the second instance not have the right backup and be non fonctional when needed
      CPCMD="rsync -a -e ";
    fi
  fi
  if [ "$MODE" == "0" ] || [ "$MODE" == "etc" ]; then
    TYPE="remote"
    OBJECT="etc"
    LFIC=${LFICETC}
    RFIC=${FICETC}
    SRFIC=${SFICETC}
    if [ ${REMOTETECHNO} -eq 4 ]; then
      LOCALSYNCDIR="$LOCALBACKUPDIR/"
      REMOTERSYNCDIR="${REMOTEBACKUPDIR}${LOCALBACKUPDIR}"
    fi
    do_remote_copy;
  fi

  if [ "$MODE" == "0" ] || [ "$MODE" == "scripts" ]; then 
    OBJECT="scripts"
    LFIC=${LFICSCRIPT}
    RFIC=${FICSCRIPT}
    SRFIC=${SFICSCRIPT}
    if [ ${REMOTETECHNO} -eq 4 ]; then
      LOCALSYNCDIR="$LOCALBACKUPDIR/"
      REMOTERSYNCDIR="${REMOTEBACKUPDIR}${LOCALBACKUPDIR}"
    fi
    do_remote_copy;
  fi

  if [ $ver \> $minimalversion ]  && ([[ "$MODE" == "0" ]] || [[ "$MODE" == "kvdump" ]] || [[ "$MODE" == "kvauto" ]]); then
    OBJECT="kvdump"
    LFIC=${LFICKVDUMP}
    RFIC=${FICKVDUMP}
    SRFIC=${SFICKVDUMP}
    if [ ${REMOTETECHNO} -eq 4 ]; then
      LOCALSYNCDIR="${SPLUNK_DB}/kvstorebackup/"
      REMOTERSYNCDIR="${REMOTEBACKUPDIR}${SPLUNK_DB}/kvstorebackup/"
    fi
    do_remote_copy;
  elif [[ "$MODE" == "0" ]] || [[ "$MODE" == "kvauto" ]]; then
    OBJECT="kvstore"
    LFIC=${LFICKVSTORE}
    RFIC=${FICKVSTORE}
    SRFIC=${SFICKVSTORE}
    if [ ${REMOTETECHNO} -eq 4 ]; then
      LOCALSYNCDIR="$LOCALBACKUPDIR/"
      REMOTERSYNCDIR="${REMOTEBACKUPDIR}${LOCALBACKUPDIR}"
    fi
    do_remote_copy;
  fi

  if [ "$MODE" == "0" ] || [ "$MODE" == "state" ]; then
    OBJECT="state"
    LFIC=${LFICSTATE}
    RFIC=${FICSTATE}
    SRFIC=${SFICSTATE}
    if [ ${REMOTETECHNO} -eq 4 ]; then
      LOCALSYNCDIR="$LOCALBACKUPDIR/"
      REMOTERSYNCDIR="${REMOTEBACKUPDIR}${LOCALBACKUPDIR}"
    fi
    do_remote_copy;
  fi
  if [ ${REMOTETECHNO} -eq 4 ]; then
    if ((  RSYNCREMOTEDELETE == 2 )); then 
      debug_log "INFO: launching remote splunkconf-purgebackup.sh"
      RESPURGE=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} ${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-purgebackup.sh`
    fi
    if (( RSYNCDISABLEREMOTE == 1 )); then
      debug_log "INFO: Disabling remote splunk (just in case as should be already stopped to prevent a clone conflict  situation"
      RESSTOP=`$OPTION ${RSYNCREMOTEUSER}@${RSYNCHOST} "${SPLUNK_HOME}/bin/splunk status && ${SPLUNK_HOME}/bin/splunk stop"`
    fi
  fi
if [ $DOREMOTEBACKUP -eq 0 ]; then
	debug_log "no remote backup requested"
fi


if [ "$INIT" == "1" ]; then
  echo_log "INIT mode , removing lock file so other backup process may run"
  `rm ${SPLUNK_HOME}/var/run/splunkconf-init.lock`
fi

debug_log "MODE=$MODE, end of splunkconf_backup script"

