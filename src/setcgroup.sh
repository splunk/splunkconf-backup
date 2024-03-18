#!/bin/bash

# Copyright 2024 Splunk Inc.
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

# This script test cgroup version and will reconfigure it in v1 compatibility mode if v2 is used
# This need to be done only for Splunk versions not supporting cgroupv2 (as when cgroupv2 will be supported , it will allow WLM to leverage cgroupv2 only functionalities) 
# This need a reboot to be taken into account 

# script return code
# 0 = all good
# 1 = need reboot

# 20240316 extract cgroup logic fron splunkconf-cloud-recovery. sh in a specific script to make it easier to use outside recovery

cgroup_status () {
  NEEDCGROUPDISABLED=0
  TEST1=$(stat -fc %T /sys/fs/cgroup/)
  if [ -e /sys/fs/cgroup/unified/ ]; then
    echo "identified cgroupsv2 with unified off, disabling unified was done"
  elif [ $TEST1 = "cgroup2fs" ]; then
    echo "identified cgroupv2 with unified on, need disabling"
    NEEDCGROUPDISABLED=1
  else
    echo "cgroupsv1, nothing to do"
  fi
}

force_cgroupv1 () {
  if [[ $NEEDCGROUPDISABLED == 1 ]]; then
    echo "Forcing cgroupv1 compatibility mode (systemd.unified_cgroup_hierarchy=0) (need reboot) (needed for RH9/Centos 9/AL2023 and all newer distributions at the moment until cgroupv2 mode supported)"
    grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
    NEEDREBOOT=1
  else
    echo "INFO : no need to disable cgroupsv2"
  fi
}

NEEDREBOOT=0
cgroup_status
force_cgroupv1

echo "returning NEEDREBOOT=$NEEDREBOOT"
exit $NEEDREBOOT
