#!/bin/bash  
exec > /tmp/splunkconf-restore-debug.log  2>&1

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

# This script restore kvdump at Splunk start if needed
# This script also does a preventive log file rotation 

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
# 20200203 restore (kvdump) version
# 20200413 small change to how we build file and path var to handle more cases + add checkpoint file to be used by splunkconf-aws-recovery script in order to prevent breaking during a huge kvdump restore, increase allowed time for big kvdump and/or slow env
# 20200413 add timer at start to allow kvstore some time to finish initializing and to avoid trying a restore is splunk is just being restarted as part of a installation script (prevent race condition)
# 20200414 add comments about possible error/solution when restore fail in some conditions
# 20201105 add /bin to PATH as required for AWS1
# 20220326 add preventive log file rotation and improve logging by moving part to debug
# 20230913 add version variable, sync code for splunkconf-backup.conf detection
# 20231204 small log change + add SPLUNK_HOME variable for lock file
# 20231204 serialize to do full back after kvdump restore 
# 20232120 more serialize at start with purge followed by init backup

VERSION="20231210b"

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
# unsetting env to not depend on splunk python version 
# this is because we may call aws command which is in python itself and can break du to this
unset LD_LIBRARY_PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin
unset PYTHONHASHSEED
unset NODE_PATH
unset PYTHONPATH
#env


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


# KVSTORE Backup options
# stop splunk for kvstore backup (that can be a bad idea if you have cluster and stop all instances at same time or whitout maintenance mode)
# risk is that data could be corrupted if something is written to kvstore while we do the backup
#RESTARTFORKVBACKUP=1
# default path, change if you need, especially if you customized splunk_db
KVDBPATH="${SPLUNK_DB}/kvstore"

#minfreespace

# 5000000 = 5G
# should we try to restore in low disk confition -> if the value is too high, that is not ideal as we probably want to restore
# in all case, the disk should be sized correctly initially for the restore to be sucesfull
# note the kvdump format and the real space on disk are linked but not directly (for example a emppty kvdump will still create kvstore files)
MINFREESPACE=2000000
CURRENTAVAIL=`df --output=avail -k  ${LOCALBACKUPDIR} | tail -1`

# logging
# file will be indexed by local splunk instance
# allowing dashboard and alerting as a consequence
LOGFILE="${SPLUNK_HOME}/var/log/splunk/splunkconf-backup.log"


###### END default parameters
SCRIPTNAME="splunkconf-restore"


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

function rotate_log {
  if [ -e "${LOGFILE}.4" ]; then
    rm ${LOGFILE}.4  || fail_log "could not remove old file ${LOGFILE}.4 , please check permissions"
    debug_log "removing oldest log file ${LOGFILE}.4"
  fi
  for i in 3 2 1 
  do
    if [ -e "${LOGFILE}.$i" ]; then
      let "j=i+1"
      mv ${LOGFILE}.$i ${LOGFILE}.$j  || fail_log "could not rotate log file ${LOGFILE}.$i , please check permissions"
      debug_log "rotating log file ${LOGFILE}.$i"
    fi
  done
  if [ -e "${LOGFILE}" ]; then
    echo_log "Splunk start : rotating file=${LOGFILE}"
    j=1
    mv ${LOGFILE} ${LOGFILE}.$j  || fail_log "could not rotate log file ${LOGFILE} , please check permissions"
    echo_log "Starting new log file"
  fi
}

###### start

# %u is day of week , we may use this for custom purge
TODAY=`date '+%Y%m%d-%H%M_%u'`;
ID=`date '+%s'`;



debug_log "checking that we were not launched by root for security reasons"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
   fail_log "Exiting ! This script must be run as splunk user, not root !" 
   exit 1
fi

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
# take over over default and local
if [[ -f "${SPLUNK_HOME}/system/local/splunkconf-backup.conf" ]]; then
  . ${SPLUNK_HOME}/system/local/splunkconf-backup.conf && (echo_log "splunkconf-backup.conf system local succesfully included")
else
  debug_log "splunkconf-backup.conf in system/local not present, no need to include it"
fi



# ARGUMENT CHECK
if [ $# -eq 2 ]; then
  debug_log "Your command line contains $# argument"
  MODE=$1
  FILE=$2
elif [ $# -gt 2 ]; then
  warn_log "Your command line contains too many ($#) arguments. Ignoring the extra data"
  MODE=$1
  FILE=$2
elif [ $# -eq 1 ]; then
  debug_log "Your command line contains $# argument"
  MODE=$1
  FILE=""
  if [ "${MODE}" = "kvdumprestore" ]; then
    debug_log "OK: got one arg only but this is kvdumprestore situation from input at start"
  else
    fail_log "ATTENTION: invalid MODE=$MODE or missing second arg for file. Exiting, please correct arguments"
    exit 1
  fi
else
  debug_log "No arguments given, running with kvdump restore and assuming called via inputs (or it will block)"
  MODE="kvdumprestore"
fi

# set root for restore here if not kvdump
RESTOREPATH=$SPLUNK_HOME

debug_log "$0 running with MODE=${MODE}"

case $MODE in
  "etcrestore"|"staterestore"|"scriptsrestore") 
     debug_log "argument valid, we are in autorestoremode with MODE=$MODE and FILE=$FILE"
     if [ -e $FILE ]; then
       tar -C ${RESTOREPATH} -xf $FILE
       exit 0
     else
       fail_log "MODE=$MODE  file=$FILE file is not present on filesystem, something wrong , impossible to restore it,please investigate"
       exit 1
     fi
   ;;
  "kvdumprestore") debug_log "argument valid , we are in kvdump restor emode" ;;
  *) fail_log "argument $MODE is NOT a valid value, please fix"; exit 1;;
esac

# from here we are in kvdump restore mode called via input at start time

###### LOCK   #######
# we need to set lock asap so if other input start it will see the lock
`touch ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`

###### Rotate ########
rotate_log;

debug_log "sleeping one minute to prevent race condition at kvstore start"
sleep 60
debug_log "done sleeping, starting real restore"


if [[ ${MINFREESPACE} -gt ${CURRENTAVAIL} ]]; then
	fail_log "minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} result=insufficientspaceleft ERROR : Insufficient disk space left , disabling restore ! Please fix "
        if [ -e "${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock" ]; then
          `rm ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`
          echo_log "cleaning up kvstore restore lock"
        fi
	exit 1
else
	echo_log "minfreespace=${MINFREESPACE}, currentavailable=${CURRENTAVAIL} result=success min free available check OK"
fi

#if [ -z ${BACKUP+x} ]; then fail_log "BACKUP not defined in ENVSPL file. Not doing backup as requested!"; exit 0; else echo_log "BACKUP=${BACKUP}"; fi
#if [ -z ${LOCALBACKUPDIR+x} ]; then echo_log "LOCALBACKUPDIR not defined in ENVSPLBACKUP file. CANT BACKUP !!!!"; exit 1; else echo_log "LOCALBACKUPDIR=${LOCALBACKUPDIR}"; fi
if [ -z ${SPLUNK_HOME+x} ]; then 
  fail_log "SPLUNK_HOME not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!"; 
  if [ -e "${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock" ]; then
    `rm ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`
    echo_log "cleaning up kvstore restore lock"
  fi
  exit 1
else 
  echo_log "SPLUNK_HOME=${SPLUNK_HOME}"
fi
if [ -z ${SPLUNK_DB+x} ]; then 
  fail_log "SPLUNK_DB not defined in default or ENVSPLBACKUP file. CANT BACKUP !!!!";
  if [ -e "${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock" ]; then
    `rm ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`
    echo_log "cleaning up kvstore restore lock"
  fi
  exit 1
else 
  echo_log "SPLUNK_DB=${SPLUNK_DB}"
fi


HOST=`hostname`;

#SERVERNAME=`grep guid ${SPLUNK_HOME}/etc/instance.cfg`;
# warning may contain spaces, line with comments ...
SERVERNAME=`grep ^serverName ${SPLUNK_HOME}/etc/system/local/server.conf  | awk '{print $3}'`
# disabled : require logged in user...
#SERVERNAME=`${SPLUNK_HOME}/bin/splunk show servername  | awk '{print $3}'`
#splunk show servername
 
if [ ${#INSTANCE} -ge 3 ]; then 
  INSTANCE=$SERVERNAME
  echo_log "using servername for instance, instance=${INSTANCE} src=servername"
else 
  INSTANCE=$HOST
  echo_log "using host for instance, instance=${INSTANCE} src=host"
fi
# servername is more reliable in dynamic env like AWS 
#INSTANCE=$SERVERNAME


# creating dir

# warning : if this fail because splunk can't create it, then root should create it and give it to splunk"
# this is context dependant


cd /

FIC="disabled"
#if [ -z ${BACKUPKV+x} ]; then echo_log "backuptype=kvstore result=disabled"; else
  version=`${SPLUNK_HOME}/bin/splunk version | cut -d ' ' -f 2`;
  if [[ $version =~ ^([^.]+\.[^.]+)\. ]]; then
    ver=${BASH_REMATCH[1]}
    #echo_log "current major version is=$ver"
  else
    fail_log "splunk version : unable to parse string $version"
  fi
  minimalversion=7.0
  kvdump_done=0
  kvbackupmode=taronline
  MESSVER="currentversion=$ver, minimalversion=${minimalversion}";
  # bc not present on some os changing if (( $(echo "$ver >= $minimalversion" |bc -l) )); then
  if [ $ver \> $minimalversion ]; then
    kvbackupmode=kvdump
    #echo_log "splunk version 7.1+ detected : using online kvstore backup "
    # important : this need passauth correctly set or the script could block !
    read sessionkey
    # get the management uri that match the current instance (we cant assume it is always 8089)
    #disabled we dont want to log this for obvious security reasons debug: echo "session key is $sessionkey"
    #MGMTURL=`${SPLUNK_HOME}/bin/splunk btool web list settings --debug | grep mgmtHostPort | grep -v \#| cut -d ' ' -f 4|tail -1`
    MGMTURL=`${SPLUNK_HOME}/bin/splunk btool web list settings --debug | grep mgmtHostPort | grep -v \# | sed -r 's/.*=\s*([0-9\.:]+)/\1/' |tail -1`
    KVARCHIVE="backupconfsplunk-kvdump-toberestored.tar.gz"
    LFICKVDUMP="${SPLUNK_DB}/kvstorebackup/${KVARCHIVE}"
    if [ -e "${LFICKVDUMP}" ]; then 
       # we are restoring as the backup file has been pushed there by the recovery script
      MESS1="MGMTURL=${MGMTURL} KVARCHIVE=${KVARCHIVE}";
      RES=`curl --silent -k https://${MGMTURL}/services/kvstore/backup/restore -X post --header "Authorization: Splunk ${sessionkey}" -d"archiveName=${KVARCHIVE}"`
      echo_log "KVDUMP RESTORE RES=$RES"
# if splunk cant find the file, it will outout sonething like that, which will be in the error message (but should not happen because -e check above) 
# <?xml version="1.0" encoding="UTF-8"?>
#<response>
#  <messages>
#    <msg type="ERROR">Specified Archive 'backupconfsplunk-kvdump-toberestored' not found in /opt/splunk/var/lib/splunk/kvstorebackup. Archives available:
#backupconfsplunk-kvdump-toberestored.tar.gz
#</msg>
#  </messages>
#</response> 


# succesfull res look like
#<!--This is to override browser formatting; see server.conf[httpServer] to disable. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .-->
#<?xml-stylesheet type="text/xml" href="/static/atom.xsl"?>
#<feed xmlns="http://www.w3.org/2005/Atom" xmlns:s="http://dev.splunk.com/ns/rest" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
#  <title>kvstorebackup</title>
#  <id>https://127.0.0.1:8089/services/kvstore/backup</id>
#  <updated>date here</updated>
#  <generator build="86fd62efc3d7" version="7.3.5"/>
#  <author>
#    <name>Splunk</name>
#  </author>
#  <opensearch:totalResults>0</opensearch:totalResults>
#  <opensearch:itemsPerPage>30</opensearch:itemsPerPage>
#  <opensearch:startIndex>0</opensearch:startIndex>
#  <s:messages/>
#</feed> 

      COUNTER=99
      RES=""
      # wait a bit (up to 20*10= 200s) for restore to complete, especially for big kvstore/busy env (io)
      # increase here if needed (ie take more time !)
      until [[  $COUNTER -lt 1 || -n "$RES"  ]]; do
        RES=`curl --silent -k https://${MGMTURL}/services/kvstore/status  --header "Authorization: Splunk ${sessionkey}" | grep backupRestoreStatus | grep -i Ready`
        #echo_log "RES=$RES"
        echo_log "COUNTER=$COUNTER $MESSVER $MESS1 kvbackupmode=$kvbackupmode "
        let COUNTER-=1
        sleep 30
      done
      #echo_log "RES=$RES"
      if [[ -z "$RES" ]];  then
	warn_log "COUNTER=$COUNTER $MESSVER $MESS1 object=$kvbackupmode result=failure ATTENTION : we didnt get ready status ! Either restore kvstore (kvdump) has failed or takes too long"
	kvdump_done="-1"
# FIXME, add detection here 
# kvstore may fail without having a error via the kvstore rest endpoint
# in that case , error message in splunkd.log looks like :
#04-13-2020 19:44:30.660 +0000 ERROR KVStorageProvider - An error occurred during the last operation ('saveBatchData', domain: '2', code: '4'): Failed to send "update" command with database "s_outputbAen4+myH4PImzzZrQ1P@SFE_mycollrNPu1fxvGhtmDefhPySrmi2r": Failed to read 4 bytes: socket error or timeout
#04-13-2020 19:44:30.835 +0000 ERROR KVStoreAdminHandler - KVStore Restore encountered problem:  response='[ "{ \"ErrorMessage\" : \"Failed to send \\\"update\\\" command with database \\\"s_outputbAen4+myH4PImzzZrQ1P@SFE_mycollrNPu1fxvGhtmDefhPySrmi2r\\\": Failed to read 4 bytes: socket error or timeout\" }" ]'
# current workaround (implentented via limits in splunkconf app is to increase some limits 
# also please check for RN 
# SPL-154925 (fixed long time ago)
# SPL-173029 (hang at busy apply for large collection, fixed, available in 7.2.11, 7.3.6, 8.0.3 
      else
	kvdump_done="1"
	LFICKVDUMP="${SPLUNK_DB}/kvstorebackup/${KVARCHIVE}"
	echo_log "COUNTER=$COUNTER $MESSVER $MESS1 object=$kvbackupmode dest=${LFICKVDUMP} result=success kvstore online (kvdump) restore complete"
      fi
      echo_log "renaming local backup file to avoid restoring it again at next start"
      LFICKVDUMP2=${LFICKVDUMP}."processed"
      # backuprestore dir should be owned by splunk or the operation will fail and the restore op will occur at each start which you dont want !
      `mv ${LFICKVDUMP} ${LFICKVDUMP2}` || fail_log "cant rename ${LFICKVDUMP} . Please correct asap and give write permission to splunk user on backuprestore dir at ${SPLUNK_DB}/kvstorebackup OR the restore operation will be repeated at next Splunk start, which you probably dont want !";
    else
      echo_log "Splunk started but not in restore situation, Nothing to do, all fine";
      #if [ -e "${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock" ]; then
      #  `rm ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`
      #  warn_log "ERROR: cleaning up stale kvstore restore lock! This is not expected, please investigate and check for issues that could have killed the restore in the middle !"
      #fi
    fi
  else
    echo_log "object=kvdump action=unsupportedversion splunk_version not yet 7.1, cant use online kvdump restore, nothing to do here, please restore outside this script"
    kvbackupmode=taronline
# temo
   fi
#fi

if [ -e "${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock" ]; then
  `rm ${SPLUNK_HOME}/var/run/splunkconf-kvrestore.lock`
  echo_log "cleaning up kvstore restore lock"
fi

echo_log "launching initial purgebackupi (to maximize chance to have enpigh space for doing backups now)"
$SPLUNK_HOME/etc/apps/splunkconf-backup/bin/splunkconf-purgebackup.sh 
echo_log "launching initial backup"
echo $sessionkey | $SPLUNK_HOME/etc/apps/splunkconf-backup/bin/splunkconf-backup.sh init 

echo_log "end of splunkconf_restore script"

