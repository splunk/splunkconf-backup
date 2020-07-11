#!/bin/bash 
exec > /tmp/splunkconf-purgebackup-debug.log  2>&1

# Matthieu Araman, Splunk


# This script purge old backups depending on the parameters set in ENVSPL

# 20170123 purge script iassoaicted to backup script
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
LOCALMAXSIZE=8100000000 
#5G
#LOCALMAXSIZE=2000000000 #2G

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
  DEBUG="0";
  # change me here, not yet in conf file
  #DEBUG="1";
  if [ $DEBUG -ne "0" ]; then 
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
debug_log "loading splunkconf-backup.conf file"
. ./default/splunkconf-backup.conf && (debug_log "splunkconf-backup.conf default succesfully included") || (debug_log "splunkconf-backup.conf default  not found or not readable. Using defaults from script ")
. ./local/splunkconf-backup.conf && (debug_log "splunkconf-backup.conf local succesfully included") || (debug_log "splunkconf-backup.conf local not found or not readable. Using defaults ")
if [[ -f "${SPLUNK_HOME}/system/local/splunkconf-backup.conf" ]]; then
  . ${SPLUNK_HOME}/system/local/splunkconf-backup.conf && (debug_log "splunkconf-backup.conf system local succesfully included")
fi

LOCALKVDUMPDIR="${SPLUNK_DB}/kvstorebackup"

if [ -z ${LOCALBACKUPRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPRETENTIONDAYS. Exiting !"; exit 1; else debug_log "LOCALBACKUPRETENTIONDAYS defined and set to ${LOCALBACKUPRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPKVRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPKVRETENTIONDAYS. Exiting !"; exit 1; else debug_log "LOCALBACKUPKVRETENTIONDAYS defined and set to ${LOCALBACKUPKVRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPSCRIPTSRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPSCRIPTSRETENTIONDAYS. Exiting !"; exit 1; else debug_log "LOCALBACKUPSCRIPTSRETENTIONDAYS defined and set to ${LOCALBACKUPSCRIPTSRETENTIONDAYS}"; fi
if [ -z ${LOCALBACKUPMODINPUTRETENTIONDAYS+x} ]; then fail_log "missing parameter LOCALBACKUPMODINPUTRETENTIONDAYS. Exiting !"; exit 1; else debug_log "LOCALBACKUPMODINPUTRETENTIONDAYS defined and set to ${LOCALBACKUPMODINPUTRETENTIONDAYS}"; fi
if [ -z ${SPLUNK_HOME+x} ]; then fail_log "SPLUNK_HOME not defined in ENSPL file !!!!"; exit 1; else debug_log "SPLUNK_HOME defined to ${SPLUNK_HOME}"; fi
if [ -z ${LOCALBACKUPDIR+x} ]; then fail_log "LOCALBACKUPDIR not defined in ENSPL file !!!!"; exit 1; else debug_log "LOCALBACKUPDIR defined and set to ${LOCALBACKUPDIR}"; fi
if (( ${LOCALMAXSIZE} > 1000000000 )); then 
  debug_log "LOCALMAXSIZE=${LOCALMAXSIZE} value check ok" 
else 
  fail_log "LOCALMAXSIZE=${LOCALMAXSIZE} value check KO ! Need to be at least 1G(1000000000). Exiting to avoid deletion of all backups on invalid value"
  exit 1;
fi

# -delete option to find does the delete

# LOCAL
# this contain the latest versions of backup so we dont erase them even in low disk conditions
TYPE="local"
EXCLUSION_LIST=""

REASON="age" 
# etc
OBJECT="etc"
A=`ls -tr ${LOCALBACKUPDIR}/backupconfsplunk-${OBJECT}*tar.gz| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"

# delete with exclusion of latest backup of this type
#/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-state*tar.gz" ! -wholename $A \) -print0 | xargs --null -I {} echo "action=purge type=local reason=retentionpolicy object=state result=success localbackupdir=${LOCALBACKUPDIR} dest={} retentiondays=${LOCALBACKUPSTATERETENTIONDAYS} purge local state backup done"  

/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
# || fail_log "action=purge type=local reason=retentionpolicy object=etc result=fail error purging local etc backup "

# kv tar version
OBJECT="kvstore"
A=`ls -tr ${LOCALBACKUPDIR}/backupconfsplunk-kvstore*tar.gz| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
#/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-kvstore*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=local reason=retentionpolicy object=kvstore result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPKVRETENTIONDAYS} purge local kv backup done" || fail_log "action=purge type=local reason=retentionpolicy object=kvstore result=fail error purging local kv backup "

# kv dump version
OBJECT="kvdump"
A=`ls -tr ${LOCALKVDUMPDIR}/backupconfsplunk-kvdump*tar.gz| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
#/usr/bin/find ${LOCALKVDUMPDIR} -type f \( -name "backupconfsplunk-kvdump*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=local reason=retentionpolicy object=kvdump result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPKVRETENTIONDAYS} purge local kv dump done" || fail_log "action=purge type=local reason=retentionpolicy object=kvdump result=fail error purging local kv dump "

# scripts
OBJECT="scripts"
A=`ls -tr ${LOCALBACKUPDIR}/backupconfsplunk-script*tar.gz| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
#/usr/bin/find ${LOCALBACKUPDIR} \( -name "backupconfsplunk-script*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPSCRIPTSRETENTIONDAYS} -print -delete && echo_log "action=purge type=local reason=retentionpolicy object=scripts result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPSCRIPTSRETENTIONDAYS} purge local scripts backup done" || fail_log "action=purge type=local reason=retentionpolicy object=scripts result=fail error purging local scripts backup "

# modinput (for upgrade, newer version only create state)
OBJECT="modinput"
A="na"
# we may remove all versions after retention as we will now have state
/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
#/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-modinput*tar.gz" -mtime +${LOCALBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=local reason=retentionpolicy object=modinput result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPMODINPUTRETENTIONDAYS} purge local modinput backup done" || fail_log "action=purge type=local reason=retentionpolicy object=modinput result=fail error purging local modinput backup "

# state
OBJECT="state"
A=`ls -tr ${LOCALBACKUPDIR}/backupconfsplunk-state*tar.gz| tail -1`
A=${A:-"na"}
EXCLUSION_LIST="${EXCLUSION_LIST} ! -wholename $A"
# delete with exclusion of latest backup of this type
/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-${OBJECT}*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPRETENTIONDAYS} -print0 -delete | xargs --null -I {}  echo_log "action=purge type=$TYPE reason=${REASON} object=${OBJECT} result=success  dest={}   retentiondays=${LOCALBACKUPRETENTIONDAYS} "
#/usr/bin/find ${LOCALBACKUPDIR} -type f \( -name "backupconfsplunk-state*tar.gz" ! -wholename $A \) -mtime +${LOCALBACKUPSTATERETENTIONDAYS} -print -delete && echo_log "action=purge type=local reason=retentionpolicy object=state result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPSTATERETENTIONDAYS} purge local state backup done" || fail_log "action=purge type=local reason=retentionpolicy object=state result=fail error purging local state backup "

# delete on size
REASON=size
CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump* | cut -f1 | tail -1`
#LASTSIZE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f -name "*.tar.gz" -printf '%Cs %p\n'|sort -rn | tail -1`
#CURRENTSIZE=`echo ${LASTSIZE} | cut -d ' ' -f 1`
debug_log "checking purge on size action=checksize currentlocalsize=${CURRENTSIZE},currentmaxlocalsize=${LOCALMAXSIZE} EXCLUSION_LIST=${EXCLUSION_LIST}"
EXITSIZE=0
while [ ${CURRENTSIZE} -gt ${LOCALMAXSIZE} ];
do 
  debug_log " in current size loop, need to purge !"
  #OLDESTFILE=`ls -t ${LOCALBACKUPDIR}/backup* | tail -1`;
  #OLDESTFILE=`echo ${LASTSIZE} | cut -d ' ' -f 2 | tail -1`;
  for OBJECT in "etc" "scripts" "kvstore" "kvdump" "modinput" "state"; 
  do
    debug_log " in current size and object (${OBJECT}) loop"
    OLDESTFILE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f \( -name "*.tar.gz" ${EXCLUSION_LIST} \) -printf '%Cs %p\n'|sort -rn | cut -d ' ' -f 2 | tail -1`
    OLDESTFILE=${OLDESTFILE:-"na"}
    if [ -e ${OLDESTFILE} ]; then
      rm -f ${OLDESTFILE}  && RES="success" || RES="failure";
      CURRENTSIZEPRE=${CURRENTSIZE}
      CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump*| cut -f1 | tail -1`
      echo_log "action=purge type=$TYPE reason=$REASON object=${OBJECT} dest=${OLDESTFILE}  localsizepre=${CURRENTSIZEPRE} localsize=${CURRENTSIZE} maxlocalsize=${LOCALMAXSIZE} result=$RES"
      #LASTSIZE=`find ${LOCALBACKUPDIR} ${LOCALKVDUMPDIR}  -type f -name "*.tar.gz" -printf '%Cs %p\n'|sort -rn | tail -1`
      #CURRENTSIZE=`echo ${LASTSIZE} | cut -d ' ' -f 1`
      debug_log "checking purge on size action=checksize currentlocalsize=${CURRENTSIZE},currentmaxlocalsize=${LOCALMAXSIZE} "
    else
      CURRENTSIZEPRE=${CURRENTSIZE}
      CURRENTSIZE=`du -c --bytes ${LOCALBACKUPDIR}/backup* ${LOCALKVDUMPDIR}/*kvdump*| cut -f1 | tail -1`
      echo_log "action=nopurge type=$TYPE reason=$REASON object=${OBJECT} dest=${OLDESTFILE}  localsizepre=${CURRENTSIZEPRE} localsize=${CURRENTSIZE} maxlocalsize=${LOCALMAXSIZE} result=\"nobackupcandidate\" starving condition "
      # we must exit loop, we cant purge more
      EXITSIZE=1
      break;
    fi
  done
  if [ ${EXITSIZE} -eq 1 ]; then
    debug_log "forwarding starving condition size exit to underlying loop"
    # alternatively we could add a condition to while
    break;
  #else 
  #  debug_log "not in starving condition, continuing through normal loop"
  fi  
done;


################ REMOTE 

TYPE="remote"


# note : only implemented for nas type currently, implicitely you have use the date versioned files for this to work correctly
if [ -z ${REMOTEBACKUPDIR+x} ]; then 
  debug_log "REMOTEBACKUPDIR not defined, remote purge disabled"; exit 0; 
elif [[ ${REMOTEBACKUPDIR} == s3* ]] ; then
  # by design, we should not be able to delete here
  debug_log "REMOTEBACKUPDIR is on s3, remote purge disabled, please use lifecycle policy in object store to remove oldest versions"; exit 0;
else
  debug_log "REMOTEBACKUP"
  # adding instance name , we only want to purge the data for this instance !
  SERVERNAME=`grep serverName ${SPLUNK_HOME}/etc/system/local/server.conf  | awk '{print $3}'`
  # servername is more reliable ithan host in dynamic env like AWS
  INSTANCE=$SERVERNAME
  REMOTEBACKUPDIR="${REMOTEBACKUPDIR}/${INSTANCE}"
  debug_log "INSTANCE=${INSTANCE}, REMOTEBACKUPDIR=${REMOTEBACKUPDIR}"
  if [ -d "${REMOTEBACKUPDIR}" ]; then
    debug_log "Starting to purging old backups"
# FIXME : reuse exclusion_list logic to always keep one backup for remote nas condition
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-etc*tar.gz" -mtime +${REMOTEBACKUPRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=etc result=success purge remote etc backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=etc result=fail   error purging remote etc backup "
    # kv tar
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-kvstore*tar.gz" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvstore result=success purge remote kv backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvstore result=fail  error purging remote kv backups"
    # kv dump
    # note after a restore the file end by tar.gz.processed, we still want to clean it up after a while
    /usr/bin/find ${REMOTEKVDUMPDIR} -type f -name "backupconfsplunk-kvdump*tar.gz*" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvdump result=success purge remote kv dump done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvdump result=fail error purging remote kv dump"
    # scripts
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-script*tar.gz" -mtime +${REMOTEBACKUPSCRIPTSRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=scripts result=success purge remote scripts backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=scripts result=fail error purging remote scripts backup"
    # modinput (upgrade case)
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-modinput*tar.gz" -mtime +${REMOTEBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=modinput result=success purge remote modinput backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=modinput result=fail error purging remote modinput backup"
    # state
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-state*tar.gz" -mtime +${REMOTEBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=state result=success purge remote state backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=state result=fail error purging remote state backup"

    # delete on size, we try to delete a whole set of backups so we hopefully have enough space for a new whole set of backups 
    while [ `du -c ${REMOTEBACKUPDIR}/backup* | cut -f1 | tail -1` -gt ${REMOTEMAXSIZE} ];
    do 
      OBJECT
      OLDESTFILE=`ls -t ${REMOTEBACKUPDIR}/backup* | tail -n1`;
      rm -f ${OLDESTFILE} && echo_log "action=purge type=$TYPE reason=size file=${OLDESTFILE} result=success" ||  fail_log "action=purge type=remote reason=size file=${OLDESTFILE} result=fail"
    done;
    debug_log "End purging old backups"
  else
    debug_log "nothing to purge, remote backup dir ${REMOTEBACKUPDIR} not found"
  fi
fi

