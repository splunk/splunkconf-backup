#!/bin/bash

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
# Description :
# this script extract from splunkconf-cloud-recovery only the initialization part for multi-ds in order to ease usage in traditional on prem env
# obviously this also mean , you are in charge to deploy OS tuning needed for DS, systemd and polkit , OS requirements , various directories , putting scripts and installation files at expected locations (feel free to look at what the recovery does, that is getting files , copying and writing at the right location)
# apps for DS that set crosschecksum and co (user-seed.conf,...) need also to be prepared by you or that will not really work

# you can rerun the script multiple times, that should work (but wont remove things)


# History
# 20211120 initial extract to distinct file
# 20220129 add fake structure to make splunkconf-backup happy
# 20221205 add variable and support for passing splunkacceptlicense option to splunkconf-init

VERSION="20221205"

SPLUNKACCEPTLICENSE="no"
#
# please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html
# then change this variable to yes as this is required to setup Splunk software

INSTALLMODE="tgz"
localrootscriptdir="/usr/local/bin"
# number of ds instances (please size accordingly to your env)
splunkdsnb=4
# replace with your org
splunkorg="org"
# replace with the version you deploy
splbinary="splunkxxxxxx.tar.gz"
SPLUNK_HOME="/opt/splunk'
localinstalldir="${SPLUNK_HOME}/var/install"
# you can change here (for example to use a custom user and group) but make sure you are still in systemd as the multids rely on it
SPLUNKINITOPTIONS=""


if [ "$INSTALLMODE" = "tgz" ]; then
  # for app inspect
  #yum groupinstall "Development Tools"
  #yum install  python3-devel
  #pip3 install splunk-appinspect
  # LB SETUP for multi DS
  #get_object ${remoteinstalldir}/splunkconf-ds-lb.sh ${localrootscriptdir}
  echo "creating DS LB via LVS"
  if [ ! -e "${localrootscriptdir}/splunkconf-ds-lb.sh" ]; then
    echo " ${localrootscriptdir}/splunkconf-ds-lb.sh doesnt  exist, please fix (add file to expected location) and relaunch"
    exit 1
  fi
  chown root. ${localrootscriptdir}/splunkconf-ds-lb.sh
  chmod 750 ${localrootscriptdir}/splunkconf-ds-lb.sh
  ${localrootscriptdir}/splunkconf-ds-lb.sh
  echo "creating fake structure and files for splunkconf-backup not to complain and report failures when backuping (as we only car about deployment-apps related stuff)"
  mkdir -p ${SPLUNK_HOME}/etc/master-apps
  mkdir -p ${SPLUNK_HOME}/etc/shcluster
  touch ${SPLUNK_HOME}/etc/passwd
  mkdir -p ${SPLUNK_HOME}/etc/openldap
  touch ${SPLUNK_HOME}/etc/openldap/ldap.conf
  mkdir -p ${SPLUNK_HOME}/etc/users
  touch ${SPLUNK_HOME}/etc/splunk-launch.conf
  touch ${SPLUNK_HOME}/etc/instance.cfg
  touch ${SPLUNK_HOME}/etc/.ui_login
  mkdir -p ${SPLUNK_HOME}/etc/licenses
  touch ${SPLUNK_HOME}/etc/log.cfg
  mkdir -p ${SPLUNK_HOME}/etc/disabled-apps
  mkdir -p ${SPLUNK_HOME}/var/run/splunk
  chown -R splunk. ${SPLUNK_HOME}
  NBINSTANCES=4
  if [ -z ${splunkdsnb+x} ]; then
    echo "multi ds mode used but splunkdsnb tag not defined, using 4 instances (default)"
  else
    NBINSTANCES=${splunkdsnb}
    if (( $NBINSTANCES > 0 )); then
      echo "set NBINSTANCES=${splunkdsnb} "
   else
      echo " ATTENTION ERROR splunkdsnb is not numeric or contain invalid value, switching back to default 4 instances, please investigate and correct tag (remove extra spaces for example"
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
    ${localrootscriptdir}/splunkconf-init.pl --no-prompt --splunkacceptlicense=$SPLUNKACCEPTLICENSE --splunkorg=$splunkorg --service-name=$SERVICENAME --splunkrole=ds --instancenumber=$i --splunktar=${localinstalldir}/${splbinary} ${SPLUNKINITOPTIONS}
  done
fi

