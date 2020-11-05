#!/bin/bash 
exec > /tmp/splunkconf-checkbackup-debug.log  2>&1

# Matthieu Araman, Splunk


# This script check backup existency
# it may be called via rest api from MC healtcheck or other usage

# 20200305 initial version 
# 20201105 add python3 protection with AWS1 support and test for conf file inclusion to improve logging

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


#### purge parameters

##### LOCAL

# Used for checking that backup is more recent than this value, dont forget to add a margin related to backup frequency as the backup time may change slightly even if theorically running at same time
BACKUPRECENCY=86500

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

LOCALMAXSIZE=5000000000 
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
SCRIPTNAME="splunkconf-checkbackup"


###### function definition

function echo_log_ext {
  LANG=C
    #NOW=(date "+%Y/%m/%d %H:%M:%S")
    NOW=(date)
    echo `$NOW`" ${SCRIPTNAME} $1 " >> $LOGFILE
  }

  function debug_log {
    echo_log_ext  "DEBUG id=$ID $1"
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
if [[ -f "./default/splunkconf-backup.conf" ]]; then
  . ./default/splunkconf-backup.conf
  debug_log "splunkconf-backup.conf default succesfully included"
else
  debug_log "splunkconf-backup.conf default  not found or not readable. Using defaults from script"
fi

if [[ -f "./local/splunkconf-backup.conf" ]]; then
  . ./local/splunkconf-backup.conf
  debug_log "splunkconf-backup.conf local succesfully included"
else
  debug_log "splunkconf-backup.conf local not present, using only default"
fi
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
  fail_log "LOCALMAXSIZE=${LOCALMAXSIZE} value check KO ! Need to be at least 1G(1000000000). Exiting to avoiod deletion of all backup on invalid value"
  exit 1;
fi


# LOCAL 
/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-etc*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=local reason=retentionpolicy object=etc result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPRETENTIONDAYS}  purge local etc backup done" || fail_log "action=check type=local reason=retentionpolicy object=etc result=fail error purging local etc backup "

# kv tar version
/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-kvstore*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=local reason=retentionpolicy object=kvstore result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPKVRETENTIONDAYS} purge local kv backup done" || fail_log "action=check type=local reason=retentionpolicy object=kvstore result=fail error purging local kv backup "
# kv dump version
/usr/bin/find ${LOCALKVDUMPDIR} -type f -name "backupconfsplunk-kvdump*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=local reason=retentionpolicy object=kvdump result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPKVRETENTIONDAYS} purge local kv dump done" || fail_log "action=check type=local reason=retentionpolicy object=kvdump result=fail error purging local kv dump "

# scripts
/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-script*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=local reason=retentionpolicy object=scripts result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPSCRIPTSRETENTIONDAYS} purge local scripts backup done" || fail_log "action=check type=local reason=retentionpolicy object=scripts result=fail error purging local scripts backup "

# modinput (for upgrade, newer version only create state)
/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-modinput*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=local reason=retentionpolicy object=modinout result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPMODINPUTRETENTIONDAYS} purge local modinput backup done" || fail_log "action=check type=local reason=retentionpolicy object=modinput result=fail error purging local modinput backup "
# state
/usr/bin/find ${LOCALBACKUPDIR} -type f -name "backupconfsplunk-state*tar.gz" -mtime-${BACKUPRECENCY} -print && echo_log "action=check type=local reason=retentionpolicy object=state result=success localbackupdir=${LOCALBACKUPDIR} retentiondays=${LOCALBACKUPSTATERETENTIONDAYS} purge local state backup done" || fail_log "action=check type=local reason=retentionpolicy object=state result=fail error purging local state backup "


# note : only implemented for nas type currently, implicitely you have use the date versioned files for this to work correctly
if [ -z ${REMOTEBACKUPDIR+x} ]; then 
  debug_log "REMOTEBACKUPDIR not defined, remote purge disabled"; exit 0; 
elif [[ ${REMOTEBACKUPDIR} == s3* ]] ; then
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
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-etc*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=remote reason=retentionpolicy object=etc result=success purge remote etc backup done" || fail_log "action=check type=remote reason=retentionpolicy object=etc result=fail   error purging remote etc backup "
    # kv tar
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-kvstore*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=remote reason=retentionpolicy object=kvstore result=success purge remote kv backup done" || fail_log "action=check type=remote reason=retentionpolicy object=kvstore result=fail  error purging remote kv backups"
    # kv dump
    # note after a restore the file end by tar.gz.processed, we still want to clean it up after a while
    /usr/bin/find ${REMOTEKVDUMPDIR} -type f -name "backupconfsplunk-kvdump*tar.gz*" -mtime -${BACKUPRECENCY} -print && echo_log "action=check type=remote reason=retentionpolicy object=kvdump result=success purge remote kv dump done" || fail_log "action=check type=remote reason=retentionpolicy object=kvdump result=fail error purging remote kv dump"
    # scripts
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-script*tar.gz" -mtime -${BACKUPRECENCY} -print && echo_log "action=check type=remote reason=retentionpolicy object=scripts result=success purge remote scripts backup done" || fail_log "action=check type=remote reason=retentionpolicy object=scripts result=fail error purging remote scripts backup"
    # modinput (upgrade case)
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-modinput*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=remote reason=retentionpolicy object=modinput result=success purge remote modinput backup done" || fail_log "action=check type=remote reason=retentionpolicy object=modinput result=fail error purging remote modinput backup"
    # state
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-state*tar.gz" -mtime -${BACKUPRECENCY} -print  && echo_log "action=check type=remote reason=retentionpolicy object=state result=success purge remote state backup done" || fail_log "action=check type=remote reason=retentionpolicy object=state result=fail error purging remote state backup"

  fi
fi

