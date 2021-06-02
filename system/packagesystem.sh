#!/bin/bash

# 20190414 add 7.2.2+ system polkit for rh7.x
# 20190517 relax perm for polkit and add comments for debugging polkit (rh7.4 require more perm than rh7.6...)
# 20191012 readd vimrc to list, restrict usage for non splunk user and more tests
# 20210415 add debian detection and custom packaging, add for-splunk in name


echo "Make sure you package of the os that the tuning belong too or the permissions will be corrupted"

# check that we are launching as root in order to access root only owned files
if [[ $EUID -ne 0 ]]; then
   fail_log "Exiting ! This script must be run as root user in order to access system files to package !" 
   exit 1
fi


TODAY=`date '+%Y%m%d'`;
ORG="org";
VERSION="7";
USER="splunk"

FILELIST="/etc/rc.d/rc.local /etc/security/limits.d/99-splunk-limits.conf /etc/sysctl.d/99-sysctl-splunk.conf /etc/udev/rules.d/71-net-txqueuelen.rules /etc/polkit-1/rules.d/99-splunk.rules /usr/local/bin/polkit_splunk /opt/splunk/.vimrc" 


if uname -a | grep --quiet -i linux ; then
   echo "Linux os : OK"
else
  echo "OS check incorrect. stopping here";
  exit 1
fi

if [ $# -eq 0 ]
  then
    echo "No arguments supplied, using default"
else 
    ORG=$1
    echo "using $ORG for org"
fi

if grep --quiet debian /etc/os-release ; then 
   VERSION="debian"
   FILELIST="/etc/security/limits.d/99-splunk-limits.conf /etc/sysctl.d/99-sysctl-splunk.conf /etc/polkit-1/localauthority/50-local.d/splunk-manage-units.pkla" 
   echo "debian os detected"
else 
   echo "rh-liked os assumed"
fi


if [[ $VERSION -eq "7" ]]; then
  if grep --quiet ${USER} /etc/passwd ; then 
    echo "${USER} user found: OK"
  else 
    echo "${USER} user doesnt exist, please create it before running this script";
    exit 1
  fi
fi

chown root.root ${FILELIST} 
if [[ $VERSION -eq "7" ]]; then
  chmod u+x /etc/rc.d/rc.local
  #FILELIST="/etc/rc.d/rc.local /etc/security/limits.d/99-splunk-limits.conf /etc/sysctl.d/99-sysctl-splunk.conf /etc/udev/rules.d/71-net-txqueuelen.rules" 
  chmod g-rwx ${FILELIST} 
  chmod 444 /etc/polkit-1/rules.d/99-splunk.rules 
  chmod 755 /usr/local/bin/polkit_splunk
  chmod 500 /etc/rc.d/rc.local
  chown splunk /opt/splunk/.vimrc
  chmod 700 /opt/splunk/.vimrc
  #chown -R ${USER}. /opt/splunk/
fi
chmod 400 /etc/sysctl.d/99-sysctl-splunk.conf
chmod 644 /etc/security/limits.d/99-splunk-limits.conf

# use current dir 
 echo -n "creating archive package-system${VERSION}-for-splunk-${ORG}-${TODAY}.tar.gz in ";pwd

tar -C"/" -zcf package-system${VERSION}-for-splunk-${ORG}-${TODAY}.tar.gz  ${FILELIST} 
#tar -C"/" -zcf package-system${VERSION}-for-splunk-${ORG}-${TODAY}.tar.gz  ${FILELIST} /opt/splunk/.vimrc 

echo "done"
