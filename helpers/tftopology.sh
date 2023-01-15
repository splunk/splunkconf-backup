#!/bin/bash

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
#
# 20221229 initial version
# 20230115 add support for env variable as input to allow store input via GH secret
# 20230115 using upper case as GH automatically move to uppercase 

VERSION="20230115b"

# This script move instance tf files from and to instances-extra based on the content of topology.txt
# This simplify terraform by only populating with the files to be used and reducing creation of unused objects

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

MODE=0

if [[ -z "${TOPOLOGY}" ]]; then
  echo "TOPOLOGY was not provided by env variable topology. When running via GH action, please create topology as GH variable and allow tftopology.yml access to it"
  echo "you have to do this by yourself when creating a fork"
  echo "Falling back on using topology file"
  MODE=1
  filename='terraform/topology.txt'
  # if this file exist, it will be used instead of default 
  # the local file will never exist in original git repo 
  # so it is safer to use a local version to avoid overwriting by error when syncing git
  filenamelocal='terraform/topology-local.txt'

  # success by default
  status=0

  if [ -e "$filenamelocal" ]; then
    echo "OK local topology file found at $filename"
    # removing terraform dir as we are going to cd into it
    filename='topology-local.txt'
  elif [ -e "$filename" ]; then
    echo "OK topology file found at $filename, please consider using a local version by creating ${filename-local} to prevent conflict when updating git files later on"
    # removing terraform dir as we are going to cd into it
    filename='topology.txt'
  else
    echo "FAIL topology file NOT found at $filename, please check and fix. Disabling topology feature for now, assuming you have done it manually"
    exit 1
  fi
else
  topo="${TOPOLOGY}"
  echo "will use topo=$topo"
  MODE=2
fi


# moving out all instance files, will readd in second step if necessary
# this is necessary in order to make sure the end list match the topology file

cd terraform
for i in instance-*.tf; do
  echo "i=$i   ."
  t=instance-extra/${i}
  if [ -e $t ]; then 
    echo "ERROR $t already exist, unable to move file $i, that is unexpected, both files should not be present at same time"
    status=1
    #exit 1
  else
    # we try git first then normal mv as the second case if for when we run outside git
    echo "moving $i to $t to clean up directory before repopulating with new list"
    if [[ `git rev-parse --is-inside-work-tree` = "true" ]]; then
      git mv $i $t  || mv $i $t
    else
      mv $i $t
    fi
  fi
done

if [[ $MODE -eq "2" ]]; then 
  # env mode
  for var in `echo "$topo" | grep -o -e "[^;,]*"`; do
    echo "using : $var";
    # ignoring comments
    [[ "$var" =~ ^#.* ]] && continue
   if [[ ${#var} -lt 2 ]] ; then
      echo "line empty or too short, ignoring..."
      continue
    fi
    # removing extra spaces just in case
    var=$(trim $var)    
    echo
    echo "Processing $var after trim in $filename"
    i=instance-${var}.tf
    t=instance-extra/$i
    if [ -e "$t" ]; then
      if [ -e "$i" ]; then
        echo "ERROR $i already exist, unable to move file $t, that is unexpected, both files should not be present at same time"
        status=1
        #exit 1
      else
        # try git first then fallback to normal mv in case we run outside git
        echo "moving $t to $i as present in topology"
        if [[ `git rev-parse --is-inside-work-tree` = "true" ]]; then
          git mv $t $i || mv $t $i
        else
          mv $t $i
        fi
      fi
    else
      echo "FAIL there is no template for $var role , please fix role name or add $t template"
      status=1
      #exit 1
    fi
  done
elif [[ $MODE -eq "1" ]]; then 
  # topology file mode
  while read var; do 
    echo "Processing $var in $filename"
    # ignoring comments
    [[ "$var" =~ ^#.* ]] && continue
    if [[ ${#var} -lt 2 ]] ; then
      echo "line empty or too short, ignoring..."
      continue
    fi
    # removing extra spaces just in case
    var=$(trim $var)    
    echo
    echo "Processing $var after trim in $filename"
    i=instance-${var}.tf
    t=instance-extra/$i
    if [ -e "$t" ]; then
      if [ -e "$i" ]; then
        echo "ERROR $i already exist, unable to move file $t, that is unexpected, both files should not be present at same time"
        status=1
        #exit 1
      else
        # try git first then fallback to normal mv in case we run outside git
        echo "moving $t to $i as present in topology"
        if [[ `git rev-parse --is-inside-work-tree` = "true" ]]; then
          git mv $t $i || mv $t $i
        else
          mv $t $i
        fi
      fi
    else
      echo "FAIL there is no template for $var role , please fix role name or add $t template"
      status=1
      #exit 1
    fi
  done < "$filename"
fi

echo "status=$status"
exit $status

