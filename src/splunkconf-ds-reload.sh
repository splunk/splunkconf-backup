#!/bin/bash


# Copyright Splunk 2022

# Contributor Matthieu Araman

# this script launch a etc backup (include DS config) then reload DS either globally or for a specific serverclass
# note the backup is the first thing done so the instance can be recreated with the right configuration in case of crash

# 20220128 initial version
# 20220129 add serverclasses support

VERSION="20220129"

SCRIPTNAME=$0

function echo_log_ext {
    LANG=C
    #NOW=(date "+%Y/%m/%d %H:%M:%S")
    NOW=(date)
    # full version for logging and indexing log in splunk internal log
    # customize here if needed
    #LOGFILE="$SPLUNK_HOME/var/log/splunk/installesscript.log"
    #echo `$NOW`" ${SCRIPTNAME} $1 " >> $LOGFILE
    # shortest version for terminal output
    echo  $1
}


function debug_log { 
  #    echo_log_ext  "DEBUG id=$ID $1"
  DEBUG=0
  if [ $DEBUG -eq 1 ]; then
    echo_log_ext  "$1"
  fi
}

function echo_log {  
  #    echo_log_ext  "INFO id=$ID $1"
  echo_log_ext  "$1"
}

function warn_log {  
  #    echo_log_ext  "WARN id=$ID $1"
  echo_log_ext  "WARN $1"
}

function fail_log {  
  #    echo_log_ext  "FAIL id=$ID $1"
  echo_log_ext  "FAIL $1"
}

###### start

# %u is day of week , we may use this for custom purge
TODAY=`date '+%Y%m%d-%H:%M_%u'`;
ID=`date '+%s'`;
FAIL=0;


echo_log "checking user is not root"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
   echo_log "This script must be run as splunk user, not root !" 1>&2
   exit 1
fi

SPLUNK_HOME="/opt/splunk"
SPLUNK_HOME_ORIG=$SPLUNK_HOME
SPLUNK_APPS="${SPLUNK_HOME}/etc/apps"
SPLUNKCONF_BACKUP_BIN="${SPLUNK_APPS}/splunkconf-backup/bin/splunkconf-backup.sh"
SPLUNKCONF_PURGEBACKUP_BIN="${SPLUNK_APPS}/splunkconf-backup/bin/splunkconf-purgebackup.sh"

CLASSES=""

if [ $# -eq 1 ]; then
  echo_log "Will only reloadserverclass(es) $1"
  CL=$1
  CLASSES=""

  for i in $(echo $CL | sed "s/,/ /g")
  do
    debug_log "$i"
    CLASSES="${CLASSES} -class $i"
  done

  debug_log "CLASSES=$CLASSES"

elif [ $# -gt 1 ]; then
  fail_log "Too many arguments.To specify multiple classes, please use $0 class1,class2,...classn"
  exit 1
else
  echo_log "will do full reload. You could only reload specific serverclasses by using $0 class1,class2,...classn "
  CLASSES=""
fi
echo_log "SPLUNK_HOME=${SPLUNK_HOME}"

if [ ! -d "$SPLUNK_HOME" ]; then
  fail_log "SPLUNK_HOME  (${SPLUNK_HOME}) does not exist ! Please check and correct.";
  exit 1;
fi


LOGGEDIN=0;
until [[ "$LOGGEDIN" -eq "1" ]] ; do
# commented out , need to debug it
# the next splunk command will ask for login, just make sur you type the right password each time !
   echo_log "login with admin credentials"
   read -p "enter admin user (default : admin)" input
   SPLADMIN=${input:-admin}
   echo_log "SPLADMIN=${SPLADMIN}"
#
   echo -n "enter admin password and press enter"
   read -s input
   #read -p "enter admin password and press enter" input
   SPLPASS=${input}
   echo_log ""
#
   DSMODE=0
   MGTPORT="${SPLUNK_HOME}/scripts/mgtport.txt"
   if [[ -e "${MGTPORT}" ]]; then
     echo_log "multi DS detected"
     # creating dir so splunkconf-backup can log here
     mkdir -p "${SPLUNK_HOME}/var/log/splunk"
     DSMODE=1
     # multids
     #PORT=`head -1 ${MGTPORT}`
     #SPLUNK_URI="https://127.0.0.1:${PORT}"
     #echo "SPLUNK_URI=${SPLUNK_URI}."
     # note as we changed commandi path, it will figure outthe port itself
     # we only test with first instance as the password are supposed to be the same on all the instances
     SPLUNK_HOME="${SPLUNK_HOME_ORIG}/splunk_ds1"
     SPLUNK_BIN="${SPLUNK_HOME}/bin/splunk"
     if [[ -e "${SPLUNK_BIN}" ]]; then
       ${SPLUNK_HOME}/bin/splunk login -auth $SPLADMIN:$SPLPASS && LOGGEDIN=1;
     else 
       fail_log "something is messy ! cant find splunk installed in expected multids at ${SPLUNK_BIN}, please correct and relaunch"
       exit 1
     fi
   else
     echo_log ""
     DSMODE=0
     echo_log "single instance DS detected"
     ${SPLUNK_HOME}/bin/splunk login -auth $SPLADMIN:$SPLPASS && LOGGEDIN=1;
   fi
#
done

echo_log ""
echo_log "OK, logged in"

if [[ -e "${SPLUNKCONF_BACKUP_BIN}" ]]; then 
  if [[ -e "${SPLUNKCONF_PURGEBACKUP_BIN}" ]]; then
    echo_log "purging old backups to freee up space for new backups"
    `cd ${SPLUNK_APPS};${SPLUNKCONF_PURGEBACKUP_BIN}`
  else 
    fail_log "ERROR ! Missing ${SPLUNKCONF_PURGEBACKUP_BIN}"
  fi
  echo_log "Launching splunkconf-backup for etc (please wait)"
  `cd ${SPLUNK_APPS};${SPLUNKCONF_BACKUP_BIN} etc`
  echo_log "checking result for local backup"
  grep "action=backup type=local" ${SPLUNK_HOME_ORIG}/var/log/splunk/splunkconf-backup.log | tail -1 | cat
  echo_log "checking result for remote backup"
  grep "action=backup type=remote" ${SPLUNK_HOME_ORIG}/var/log/splunk/splunkconf-backup.log | tail -1 |cat
else
  warn_log "WARNING ! splunkconf-backup not installed (SPLUNKCONF_BACKUP_BIN missing), configuration backups disabled !"
fi

if [[ $DSMODE -eq "0" ]]; then
  SPLUNK_HOME="${SPLUNK_HOME_ORIG}"
  SPLUNK_BIN="${SPLUNK_HOME}/bin/splunk"
  ${SPLUNK_HOME}/bin/splunk reload deploy-server $CLASSES
  exit 0
fi

# if we are here we are in multids

MAX=100

echo_log "initiating DS reloads, System load may increase while DS rescan their configuration"

for ((i=1;i<=$MAX;i++)); 
do 
   SPLUNK_HOME="${SPLUNK_HOME_ORIG}/splunk_ds$i"
   SPLUNK_BIN="${SPLUNK_HOME}/bin/splunk"
   if [[ -e "${SPLUNK_BIN}" ]]; then
     echo_log "Reloading DS for instance $i, path=${SPLUNK_HOME}"
     # we need to login just before because du to the time it take we could be in the situation where the token expire !
     ${SPLUNK_HOME}/bin/splunk login -auth $SPLADMIN:$SPLPASS 
     ${SPLUNK_HOME}/bin/splunk reload deploy-server $CLASSES
     echo_log "reload initiated for instance $i, sleeping 30s"
     sleep 30
   else
     # no more instance, stop to loop
     break
   fi
done

echo_log "reloading has been completely initiated, DS instances may need some time to complete reload and catch up "

#
