#!/bin/bash -x
exec > /tmp/splunkconf-purgebackup-helper-debug.log  2>&1
    
# Copyright 2023 Splunk Inc.
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

LOGFILE="splunkconf-backup-purge-helper.log"

###### function definition

function echo_log_ext {
  LANG=C
  #NOW=(date "+%Y/%m/%d %H:%M:%S")
  NOW=(date)
  echo `$NOW`" ${SCRIPTNAME} $1 " >> $LOGFILE
}

function debug_log {
  DEBUG="0";
  # change me here only to debug
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


# start

if [ $# -ne 3 ]; then
   echo "ERROR: incorrect arguments, please use $0 REMOTEBACKUPDIR REMOTEBACKUPRETENTIONDAYS REMOTEMAXSIZE "
   exit 1
fi
REMOTEBACKUPDIR=$1
REMOTEBACKUPRETENTIONDAYS=$2
REMOTEMAXSIZE=$3

REMOTEBACKUPKVRETENTIONDAYS=$REMOTEBACKUPRETENTIONDAYS
REMOTEBACKUPSCRIPTSRETENTIONDAYS=$REMOTEBACKUPRETENTIONDAYS
REMOTEBACKUPMODINPUTRETENTIONDAYS=$REMOTEBACKUPRETENTIONDAYS

if [ -d "${REMOTEBACKUPDIR}" ]; then
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*etc*tar.*" -mtime +${REMOTEBACKUPRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=etc result=success purge remote etc backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=etc result=fail   error purging remote etc backup "
    # kv tar
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*kvstore*tar.*" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvstore result=success purge remote kv backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvstore result=fail  error purging remote kv backups"
    # kv dump
    # note after a restore the file end by tar.gz.processed, we still want to clean it up after a while
    /usr/bin/find ${REMOTEKVDUMPDIR} -type f -name "backupconfsplunk-*kvdump*tar.*" -mtime +${REMOTEBACKUPKVRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=kvdump result=success purge remote kv dump done" || fail_log "action=purge type=remote reason=retentionpolicy object=kvdump result=fail error purging remote kv dump"
    # scripts
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*script*tar.*" -mtime +${REMOTEBACKUPSCRIPTSRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=scripts result=success purge remote scripts backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=scripts result=fail error purging remote scripts backup"
    # state
    /usr/bin/find ${REMOTEBACKUPDIR} -type f -name "backupconfsplunk-*state*tar.*" -mtime +${REMOTEBACKUPMODINPUTRETENTIONDAYS} -print -delete && echo_log "action=purge type=remote reason=retentionpolicy object=state result=success purge remote state backup done" || fail_log "action=purge type=remote reason=retentionpolicy object=state result=fail error purging remote state backup"

    # delete on size, we try to delete a whole set of backups so we hopefully have enough space for a new whole set of backups 
    while [ `du -c ${REMOTEBACKUPDIR}/backup* | cut -f1 | tail -1` -gt ${REMOTEMAXSIZE} ];
    do 
      OBJECT
      OLDESTFILE=`ls -t ${REMOTEBACKUPDIR}/backup* | tail -n1`;
      rm -f ${OLDESTFILE} 
    done;
fi

