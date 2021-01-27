#!/bin/bash  
exec > /tmp/splunkconf-backup-debug.log  2>&1



/bin/env > /tmp/debugenv
# Matthieu Araman, Splunk
# copyright splunk

# This script backup splunk config files

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

###### BEGIN default parameters 
# dont change here, use the configuration file to override them
# note : this script wont backup any index data

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
# note : we could get this from env now that we run via input

# debug -> verify the env that splunk set (python version may affect aws command for example,...)
#env
# undetting env to not depend on splunk python version 
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

# FIXME , get it automatically from splunk-launch.conf 
SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"


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
# type 1 = nas (use cp), 2 = S3 (use aws s3 cp), 3= remote nas via scp
REMOTETECHNO=2
# type : 0=auto 1 = date versioned backup (preferred for local),2 = only one backup file (dangerous, we need other feature to do versioning like filesystem (btrfs) , classic backup on top, ... 3 = only one backup, no instance name in it (they are still sorted by instance directory, may be easier for automatic reuse by install scripts)
# auto -> S3 =0 (because s3 can store multiple versions of same file), NAS=1
REMOTETYPE=0


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
KVDBPATH="${SPLUNK_DB}/kvstore"

# fixme : move this after so that splunk_home changes apply
# state files and dir
#MODINPUTPATH="${SPLUNK_DB}/modinput"
#SCHEDULERSTATEPATH="${SPLUNK_HOME}/var/run/splunk/scheduler"
STATELIST="${SPLUNK_DB}/modinput ${SPLUNK_HOME}/var/run/splunk/scheduler ${SPLUNK_HOME}/var/run/splunk/cluster/remote-bundle ${SPLUNK_DB}/persistentstorage ${SPLUNK_DB}/fishbucket ${SPLUNK_HOME}/var/run/splunk/deploy"

# configuration for scripts backups
# script dir (what to backup)
SCRIPTDIR="${SPLUNK_HOME}/scripts"

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
  DEBUG=0   
  # uncomment for debugging
  #DEBUG=1   
  if [ "$DEBUG" == "1" ]; then 
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

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
function check_cloud() {
  cloud_type=0
  response=$(curl -fs -m 5 -H "Metadata-Flavor: Google" ${METADATA_URL})
  if [ $? -eq 0 ]; then
    echo_log 'GCP instance detected'
    cloud_type=2
  # old aws hypervisor
  elif [ -f /sys/hypervisor/uuid ]; then
    if [ `head -c 3 /sys/hypervisor/uuid` == "ec2" ]; then
      echo_log 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # newer aws hypervisor (test require root)
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
      echo_log 'AWS instance detected'
      cloud_type=1
    fi
  else
  # Fallback check of http://169.254.169.254/. If we wanted to be REALLY
  # authoritative, we could follow Amazon's suggestions for cryptographically
  # verifying their signature, see here:
  #    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
  # but this is almost certainly overkill for this purpose (and the above
  # checks of "EC2" prefixes have a higher false positive potential, anyway).
  # FIXME add imsv2 support here
    if $(curl -s -m 5 http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone) ; then
      echo_log 'AWS instance detected'
      cloud_type=1
    fi
  fi
}

###### start

# addin a random sleep to reduce backup concurrency + a potential conflict when we run at the limit in term of size (one backup type could eat the space before purge run)
sleep $((1 + RANDOM % 30))

# %u is day of week , we may use this later for custom purge logic
TODAY=`date '+%Y%m%d-%H%M%Z_%u'`;
ID=`date '+%s'`;


# initialization
ERROR=0
ERROR_MESS=""

# include VARs
APPDIR=`pwd`
debug_log "app=splunkconf-backup result=running SPLUNK_HOME=$SPLUNK_HOME splunkconfappdir=${APPDIR} loading splukconf-backup.conf file"
if [[ -f "./default/splunkconf-backup.conf" ]]; then
  . ./default/splunkconf-backup.conf
  debug_log "splunkconf-backup.conf default succesfully included"
else
  debug_log "splunkconf-backup.conf default  not found or not readable. Using defaults from script "
fi

if [[ -f "./local/splunkconf-backup.conf" ]]; then
  . ./local/splunkconf-backup.conf
  debug_log "splunkconf-backup.conf local succesfully included"
else
  debug_log "splunkconf-backup.conf local not present, using only default"   
fi 

check_cloud

echo_log "cloud_type=$cloud_type"

# we get most var dynamically from ec2 tags associated to instance

# getting tokens and writting to /etc/instance-tags

CHECK=1

if ! command -v curl &> /dev/null
then
  warn_log "oops ! command curl could not be found !"
  CHECK=0  
fi

if ! command -v aws &> /dev/null
then
  warn_log "command aws not detected, assuming we are not running inside aws"
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
    aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/'  | grep -E "^splunk" > $INSTANCEFILE/
    if grep -qi splunkinstanceType $INSTANCEFILE
    then
      # note : filtering by splunk prefix allow to avoid import extra customers tags that could impact scripts
      echo_log "filtering tags with splunk prefix for instance tags (file=$INSTANCEFILE)" 
    else
      echo_log "splunk prefixed tags not found, reverting to full tag inclusion (file=$INSTANCEFILE)" 
      aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/'  > $INSTANCEFILE
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
  echo_log "aws cloud tag detection disabled (missing commands)"
fi

if [ -e "$INSTANCEFILE" ]; then
  chmod 644 $INSTANCEFILE
  # including the tags for use in this script
  . $INSTANCEFILE
else
  warn_log "WARNING : no instance tags file at $INSTANCEFILE"
fi

if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then 
    warn_log "name=splunks3backupbucket  src=instancetags result=unset "; 
  else 
    if [[ "cloud_type" -eq 2 ]]; then
      debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
      # we already have the scheme in var for gcp
      REMOTEBACKUPDIR="${s3backupbucket}/splunkconf-backup"
      debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
    else
      debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=false";
      REMOTEBACKUPDIR="s3://${s3backupbucket}/splunkconf-backup"
      debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
    fi
  fi
else
  s3backupbucket=$splunks3backupbucket
  if [[ "cloud_type" -eq 2 ]]; then
    debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=true";
      # we already have the scheme in var for gcp
    REMOTEBACKUPDIR="${s3backupbucket}/splunkconf-backup"
    debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
  else
    debug_log "name=splunks3backupbucket src=instancetags result=set value='$s3backupbucket' splunkprefix=true";
    REMOTEBACKUPDIR="s3://${s3backupbucket}/splunkconf-backup"
    debug_log "remotebackupdir='$REMOTEBACKUPDIR'";
  fi
fi


if [[ -f "${SPLUNK_HOME}/system/local/splunkconf-backup.conf" ]]; then
  . ${SPLUNK_HOME}/system/local/splunkconf-backup.conf && (echo_log "splunkconf-backup.conf system local succesfully included") 
fi

if [[ -f "${APPDIR}/lookups/splunkconf-exclude.csv" ]]; then
  TAREXCLUDEFILE="${APPDIR}/lookups/splunkconf-exclude.csv"
else
  TAREXCLUDEFILE="/dev/null"
  warn_log "OOOPS ! we cant find splunkconf-exclude.csv in lookups directory ${APPDIR}/lookups/splunkconf-exclude.csv ! This is not expected , please correct" 
fi


debug_log "checking that we were not launched by root for security reasons"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
   fail_log "Exiting ! This script must be run as splunk user, not root !" 
   exit 1
fi

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
debug_log "splunkconf-backup running with MODE=${MODE}"

if [ -z ${BACKUP+x} ]; then fail_log "BACKUP not defined in ENVSPL file. Not doing backup as requested!"; exit 0; else debug_log "BACKUP=${BACKUP}"; fi
if [ -z ${LOCALBACKUPDIR+x} ]; then echo_log "LOCALBACKUPDIR not defined in ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "LOCALBACKUPDIR=${LOCALBACKUPDIR}"; fi
if [ -z ${SPLUNK_HOME+x} ]; then fail_log "SPLUNK_HOME not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "SPLUNK_HOME=${SPLUNK_HOME}"; fi
if [ -z ${SPLUNK_DB+x} ]; then fail_log "SPLUNK_DB not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else debug_log "SPLUNK_DB=${SPLUNK_DB}"; fi


HOST=`hostname`;

#SERVERNAME=`grep guid ${SPLUNK_HOME}/etc/instance.cfg`;
# warning may contain spaces, line with comments ...
SERVERNAME=`grep ^serverName ${SPLUNK_HOME}/etc/system/local/server.conf  | awk '{print $3}'`
# disabled : require logged in user...
#SERVERNAME=`${SPLUNK_HOME}/bin/splunk show servername  | awk '{print $3}'`
#splunk show servername
 
if [ ${#INSTANCE} -ge 3 ]; then 
  INSTANCE=$SERVERNAME
  debug_log "using servername for instance, instance=${INSTANCE} src=servername"
else 
  INSTANCE=$HOST
  debug_log "using host for instance, instance=${INSTANCE} src=host"
fi
# servername is more reliable in dynamic env like AWS 
#INSTANCE=$SERVERNAME

debug_log "checking for a ongoing kvdump restore"
if [ -e "/opt/splunk/var/run/splunkconf-kvrestore.lock" ]; then
  fail_log "splunkconf-restore is currently running a kvdump, stopping to avoid creating a incomplete backup."
  ERROR=1
  ERROR_MESSAGE="kvdumprestorelock"
  exit 1
fi

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
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-full-${INSTANCE}.tar.gz";
	MESS1="backuptype=etcfullinstanceoverwrite ";
    elif [ ${LOCALTYPE} -eq 3 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-full.tar.gz";
	MESS1="backuptype=etcfullnoinstanceoverwrite ";
    else
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-full-${INSTANCE}-${TODAY}.tar.gz";
	MESS1="backuptype=etcfullinstanceversion ";
    fi
  else
    if [ ${LOCALTYPE} -eq 2 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-targeted-${INSTANCE}.tar.gz";
	MESS1="backuptype=etctargetedinstanceoverwrite ";
    elif [ ${LOCALTYPE} -eq 3 ]; then
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-targeted.tar.gz";
	MESS1="backuptype=etctargetednoinstanceoverwrite ";
    else
	FIC="${LOCALBACKUPDIR}/backupconfsplunk-etc-targeted-${INSTANCE}-${TODAY}.tar.gz";
	MESS1="backuptype=etctargetedinstanceversion ";
    fi
  fi
  splunkconf_checkspace;
  if [ $ERROR -ne 0 ]; then
    fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}" 
  elif [ ${BACKUPTYPE} -eq 2 ]; then
    debug_log "running tar for etc full backup";
    tar -zcf ${FIC}  ${SPLUNK_HOME}/etc && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
    etc_done=1
    LFICETC=$FIC;
  else
    #debug_log "running tar for etc targeted backup
    # dump exlusion for collection app that store temp huge files in etc instead of a proper dir under var
    tar --exclude-from=${TAREXCLUDEFILE} --exclude '*/dump' -zcf ${FIC} ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/deployment-apps ${SPLUNK_HOME}/etc/master-apps ${SPLUNK_HOME}/etc/shcluster ${SPLUNK_HOME}/etc/passwd ${SPLUNK_HOME}/etc/system/local ${SPLUNK_HOME}/etc/auth ${SPLUNK_HOME}/etc/openldap/ldap.conf ${SPLUNK_HOME}/etc/users ${SPLUNK_HOME}/etc/splunk-launch.conf ${SPLUNK_HOME}/etc/instance.cfg ${SPLUNK_HOME}/etc/.ui_login ${SPLUNK_HOME}/etc/licenses ${SPLUNK_HOME}/etc/*.cfg ${SPLUNK_HOME}/etc/disabled-apps && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
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
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}.tar.gz";
    ESS1="backuptype=scriptstargetedinstanceoverwrite ";
  elif [ ${LOCALTYPE} -eq 3 ]; then
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-scripts.tar.gz";
    MESS1="backuptype=scriptstargetednoinstanceoverwrite  ";
  else
    FIC="${LOCALBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}-${TODAY}.tar.gz";
    MESS1="backuptype=scriptstargetedinstanceversion ";
  fi
  splunkconf_checkspace;
  if [ $ERROR -ne 0 ]; then
    fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
  elif [ -z ${BACKUPSCRIPTS+x} ]; then 
    # should we echo here to have it appear in stats ?
    debug_log "action=backup type=$TYPE object=${OBJECT} result=disabled dest=$FIC reason=disabled ${MESS1}" 
  else 
    #debug_log "doing backup scripts via tar";
    tar -zcf ${FIC}  ${SCRIPTDIR} && echo_log "action=backup type=$TYPE object=${OBJECT} result=success dest=$FIC ${MESS1} " || warn_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason="tar" ${MESS1}  please investigate"
    scripts_done=1
    LFICSCRIPT=$FIC;
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
  if [ -z ${BACKUPKV+x} ]; then 
    echo_log "type=$TYPE object=${OBJECT} result=disabled"; 
  else
    version=`${SPLUNK_HOME}/bin/splunk version | cut -d ' ' -f 2`;
    if [[ $version =~ ^([^.]+\.[^.]+)\. ]]; then
      ver=${BASH_REMATCH[1]}
      debug_log "splunkversion=$ver"
    else
      fail_log "splunkversion : unable to parse string $version"
    fi
    minimalversion=7.0
    kvbackupmode=taronline
    MESSVER="currentversion=$ver, minimalversionover=${minimalversion}";
    splunkconf_checkspace;
    if [ $ERROR -ne 0 ]; then
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
      KVARCHIVE="backupconfsplunk-kvdump-${TODAY}"
      MESS1="MGMTURL=${MGMTURL} KVARCHIVE=${KVARCHIVE}";
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
      if [[ -z "$RES" ]];  then
	warn_log "COUNTER=$COUNTER $MESSVER $MESS1 type=$TYPE object=$kvbackupmode result=failure dest=${LFICKVDUMP} ATTENTION : we didnt get ready status ! Either backup kvstore (kvdump) has failed or takes too long"
	kvdump_done="-1"
      else
	kvdump_done="1"
	LFICKVDUMP="${SPLUNK_DB}/kvstorebackup/${KVARCHIVE}.tar.gz"
	echo_log "COUNTER=$COUNTER $MESSVER $MESS1 action=backup type=$TYPE object=$kvbackupmode result=success dest=${LFICKVDUMP}  kvstore online (kvdump) backup complete"
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
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}.tar.gz";
        MESS1="backuptype=kvstoreinstanceoverwrite ";
        debug_log "backup for kvstore no date with instance to $FIC";
      elif [ ${LOCALTYPE} -eq 3 ]; then
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-kvstore.tar.gz";
        MESS1="backuptype=kvstorenoinstanceoverwrite ";
        debug_log "backup for kvstore no date no instance to $FIC";
      else
        FIC="${LOCALBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}-${TODAY}.tar.gz";
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
        tar -zcf ${FIC}  ${KVDBPATH}
        RES=$?
        #echo_log "res=${RES}"
        if [ $RES -eq 0 ]; then
          echo_log "${MESS1} action=backup type=$TYPE object=kvstore result=success dest=$FIC";
          KVBOK=1;
          CONTINUE=0;
        else
          warn_log "${MESS1} action=backup type=$TYPE object=kvstore result=retry kotry=${KVBKO} komax=${KVBKOMAX} dest=$FIC local kvstore backup returned error (probably file changed during backup) , please investigate";
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
  # end traditional kvstore backup
    else 
      debug_log "action=backup object=kvstore type=$TYPE result=nobackuprequested"
    fi
  fi
  LFICKVSTORE=$FIC;
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
    debug_log "start to backup state (modinput , scheduler states, bundle, fishbuckets,....)";
    if [ ${LOCALTYPE} -eq 2 ]; then
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-state-${INSTANCE}.tar.gz";
      MESS1="backuptype=stateinstanceoverwrite ";
      debug_log "backup type will be state with instance no date";
    elif [ ${LOCALTYPE} -eq 3 ]; then
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-state.tar.gz";
      MESS1="backuptype=statenoinstanceoverwrite ";
      debug_log "backup type will be state no instance no date";
    else
      FIC="${LOCALBACKUPDIR}/backupconfsplunk-state-${INSTANCE}-${TODAY}.tar.gz";
      MESS1="backuptype=stateinstanceversion ";
      debug_log "backup type will be state (date versioned with instance backup mode)";
    fi
    STATELIST2=""
    #debug_log"mode=$MODE, checking state list"
    for i in $STATELIST;
    do
      #debug_log "mode=$MODE, i=$i"
      if [ -e "$i" ]; then
        STATELIST2="${STATELIST2} $i"
        debug_log "stateverif : $i exist"
     else
        debug_log "stateverif : $i NOT exist"
     fi
    done
    debug_log "STATELIST=${STATELIST} STATELIST2=${STATELIST2}" 
    splunkconf_checkspace;
    if [ $ERROR -ne 0 ]; then
      fail_log "action=backup type=$TYPE object=${OBJECT} result=failure dest=$FIC reason=${ERROR_MESS} ${MESS1}"
    else
      #echo_log "doing backup state (modinput and scheduler state) via tar";
      #result=$(tar -zcf ${FIC}  ${MODINPUTPATH} ${SCHEDULERSTATEPATH} ${STATELIST}  2>&1 | tr -d "\n") && echo_log "${MESS1} action=backup type=local object=state result=success dest=$FIC local state backup succesfull (result=$result)" || warn_log "${MESS1} action=backup type=local object=state result=failure dest=$FIC local state backup returned error , please investigate (modinputpath=${MODINPUTPATH} schedulerpath=${SCHEDULERSTATEPATH}  statelist=${STATELIST} result=$result )"
      result=$(tar -zcf ${FIC} ${STATELIST2}  2>&1 | tr -d "\n") && echo_log "${MESS1} action=backup type=local object=state result=success dest=$FIC local state backup succesfull (result=$result)" || warn_log "${MESS1} action=backup type=local object=state result=failure dest=$FIC local state backup returned error , please investigate (statelist=${STATELIST} statelist2=${STATELIST2} result=$result )"
      state_done=1
      LFICSTATE=$FIC;
    fi
  fi
  # if mode explicit state or all
fi
debug_log "MODE=$MODE, starting remote part"

###############################    REMOTE    #############################################3

# remote techno 1 = nas, 2=S3, 3= scp to nas
# remotetype 0=auto, 1=date, 2 = no date, 3= no date, no instance

TYPE="remote"
if [ $DOREMOTEBACKUP -eq 1 ]; then
debug_log "starting remote backup"
  if [ ${REMOTETYPE} -eq 0 ]; then 
    if [ ${REMOTETECHNO} -eq 2 ]; then
      REMOTETYPE=3;
      debug_log "object store remote type with versioning, automatic switching to non date and non instance format";
    else 
      REMOTETYPE=1;
      debug_log "NAS type, automatic switching to date+instance format";
    fi
  else 
    debug_log "remote_type statically set, unchanged, it is set to ${REMOTETYPE}"
  fi
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
  # now we add the instance name or backup from different instances would collide
  REMOTEBACKUPDIR="${REMOTEBACKUPDIR}/${INSTANCE}"
  # first run we are creating that instance dir

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
  else
    fail_log "cant do remote backup. unknown remotetechno ${REMOTETECHNO}. Please fix configuration settings"
    exit 1
  fi


  cd /
  if [ ${BACKUPTYPE} -eq 2 ]; then
    if [ ${REMOTETYPE} -eq 2 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-full-${INSTANCE}.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state-${INSTANCE}.tar.gz";
        debug_log "backup type will be etc full no date";
    elif [ ${REMOTETYPE} -eq 3 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-full.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state.tar.gz";
        debug_log "backup type will be etc full no date no instance";
    else
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-full-${INSTANCE}-${TODAY}.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}-${TODAY}.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}-${TODAY}.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state-${INSTANCE}-${TODAY}.tar.gz";
        debug_log "backup type will be etc full (date versioned backup mode with instance name)";
    fi
  else
    if [ ${REMOTETYPE} -eq 2 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-targeted-${INSTANCE}.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state-${INSTANCE}.tar.gz";
        debug_log "backup type will be etc targeted no date";
    elif [ ${REMOTETYPE} -eq 3 ]; then
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-targeted.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state.tar.gz";
        debug_log "backup type will be etc targeted no date no instance ";
    else
        FICETC="${REMOTEBACKUPDIR}/backupconfsplunk-etc-targeted-${INSTANCE}-${TODAY}.tar.gz";
        FICSCRIPT="${REMOTEBACKUPDIR}/backupconfsplunk-scripts-${INSTANCE}-${TODAY}.tar.gz";
        FICKVSTORE="${REMOTEBACKUPDIR}/backupconfsplunk-kvstore-${INSTANCE}-${TODAY}.tar.gz";
        FICKVDUMP="${REMOTEBACKUPDIR}/backupconfsplunk-kvdump-${INSTANCE}-${TODAY}.tar.gz";
        FICSTATE="${REMOTEBACKUPDIR}/backupconfsplunk-state-${INSTANCE}-${TODAY}.tar.gz";
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
      CPCMD="aws s3 cp";
      OPTION=" --quiet --storage-class STANDARD_IA";
    fi
# --storage-class STANDARD_IA reduce cost for infrequent access objects such as backups while not decreasing availability/redundancy
  elif [ ${REMOTETECHNO} -eq 3 ]; then
    CPCMD="scp";
# second option depend on recent ssh , instead it is possible to disable via =no or use other mean to accept the key before the script run
    OPTION=" -oBatchMode=yes -oStrictHostKeyChecking=accept-new";
  fi
  TYPE="remote"
  OBJECT="etc"
  LFIC=${LFICETC}
  RFIC=${FICETC}
  if [ "${LFIC}" != "disabled" ]; then
  ` ${CPCMD} ${LFIC} ${RFIC} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC}" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC}"
  else
    debug_log "not doing remote $OBJECT as no local version present MODE=$MODE"
  fi
  OBJECT="scripts"
  LFIC=${LFICSCRIPT}
  RFIC=${FICSCRIPT}
  if [ "${LFIC}" != "disabled" ]; then
    ` ${CPCMD} ${LFIC} ${RFIC} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC}" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC}"
  else
    debug_log "not doing remote $OBJECT as no local version present MODE=$MODE"
  fi
  OBJECT="kvdump"
  LFIC=${LFICKVDUMP}
  RFIC=${FICKVDUMP}
  if [ "${LFIC}" != "disabled" ]; then
    if [ "${kvdump_done}" == "1" ]; then
      # 7.1+ with online backup
      debug_log "remote : kvdump ${LFICKVDUMP} to ${FICKVDUMP}"
      ` ${CPCMD} ${LFIC} ${RFIC} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC}" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC}"
     # ` ${CPCMD} ${LFICKVDUMP} ${FICKVDUMP} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=$LFICKVDUMP dest=$FICKVDUMP" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=$LFICKVDUMP dest=$FICKVDUMP remote backup kvdump to $FICKVDUMP returned error , please investigate"
    else
      debug_log "MODE=$MODE,no local kvdump, kvdump_done=${kvdump_done}, nothing to copy on remote"
    fi
  else
    debug_log "not doing remote $OBJECT as no local version present MODE=$MODE"
  fi
  OBJECT="kvstore"
  LFIC=${LFICKVSTORE}
  RFIC=${FICKVSTORE}
  if [ "${LFIC}" != "disabled" ]; then
    ` ${CPCMD} ${LFIC} ${RFIC} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC}" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC}"
    #    ` ${CPCMD} ${LFICKV} ${FICKV} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFICKV} dest=${FICKV} remote backup kvstore succesfull to $FICKV" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFICKV} dest=${FICKV} remote backup kvstore to $FICKV returned error , please investigate"
  else
      debug_log "MODE=$MODE,no local kvstore, nothing to copy remote"
  fi
  OBJECT="state"
  LFIC=${LFICSTATE}
  RFIC=${FICSTATE}
  if [ "${LFIC}" != "disabled" ]; then
    ` ${CPCMD} ${LFIC} ${RFIC} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFIC} dest=${RFIC}" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFIC} dest=${RFIC}"
    #` ${CPCMD} ${LFICSTATE} ${FICSTATE} ${OPTION}` && echo_log "action=backup type=${TYPE} object=${OBJECT} result=success src=${LFICSTATE} dest=${FICSTATE} remote backup state succesfull to $FICSTATE" || warn_log "action=backup type=${TYPE} object=${OBJECT} result=failure src=${LFICSTATE} dest=${FICSTATE} remote backup state to $FICSTATE returned error , please investigate"
  else
    debug_log "not doing remote $OBJECT as no local version present MODE=$MODE"
  fi
else 
	debug_log "no remote backup requested"
fi


debug_log "MODE=$MODE, end of splunkconf_backup script"

