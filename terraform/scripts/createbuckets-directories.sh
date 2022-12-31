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

# This script create the local bucket structure to be pushed in cloud bucket via terraform
# from the git structure

# buckets will be // to terraform directory
#
# buckets
#   buckets-install
#     install
#     packaged
#   buckets-backup
# terraform

# -> so we just cd one directory up to be at git root directory (as we are called from terraform)

cd ..

echo "************************** directory structure creation "
#createbuckets:
i=buckets
mkdir -p $i/bucket-install/install/apps
mkdir -p $i/bucket-install/packaged
# copying apps for bucket install
# Event Timeline is to be downloaded from https://splunkbase.splunk.com/app/4370/#/details
# SHA256 checksum (event-timeline-viz_160.tgz) 8dc7a5cf1faf5d2a64cb2ceae17049070d24f74c381b83f831d0c51ea15a2ffe
# SHA256 checksum (event-timeline-viz_171.tgz) 7d110b3adbcdb5342d01a42b950f0c10b55dbadc561111fce14afcee16070755
# you need this on the MC to have the dashboard viz running 
#for j in splunkconf-backup.tar.gz event-timeline-viz_171.tgz
# commenting viz from here, to be deployed via normal mechanism on MC

for j in splunkconf-backup.tar.gz 
do
  if [ -e ./install/apps/$j ]; then 
    \cp -p ./install/apps/$j "$i/bucket-install/install/apps/"
  else
    echo "ERROR : missing file ./install/apps/$j, please add it and relaunch (read comments to understand how to get file)"
  fi
done

SOURCE="src"
# copying files for bucket install in install
# splunk.secret -> you need to provide it from a splunk deployment (unique to that env)
# user-seed.conf -> to initiate splunk password, you can use splunkconf-init.pl to create it or follow splunk doc 
# splunkconf-aws-recovery.sh is renamed to splunkconf-cloud-recovery.sh, you dont need it unless you rely on user data that reference the old file name
# splunktargetenv are optional script to have custom actions on a specific env when moving between prod and test env (like disabling sending emails or alerts)
#for j in splunk.secret user-seed.conf splunkconf-cloud-recovery.sh splunkconf-upgrade-local.sh splunkconf-swapme.pl splunkconf-upgrade-local-precheck.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-prepare-es-from-s3.sh user-data.txt user-data-gcp.txt user-data-bastion.txt user-data-withcliinstall.txt splunkconf-init.pl installes.sh splunktargetenv-for*.sh splunkconf-ds-lb.sh
for j in splunkconf-cloud-recovery.sh splunkconf-upgrade-local.sh splunkconf-swapme.pl splunkconf-upgrade-local-precheck.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-prepare-es-from-s3.sh splunkconf-init.pl installes.sh splunkconf-ds-lb.sh
do
  if [ -e ./$SOURCE/$j ]; then 
    \cp -p ./$SOURCE/$j  "$i/bucket-install/install/"
   else
    echo "ERROR : missing file ./$SOURCE/$j, please read comment in script and evaluate if you need it then relaunch if necessary"
  fi
done
# splunk.secret is a file generated first time by Splunk . If you provide one, it will be deployed which ease deploying already obfuscated config in a distributed env (it may e less necessary with v9+ that automatically handle different splunk.secret in a indexer  cluster
# user-seed.conf contains hashed splunk admin password. it avoid to have admin passord in clear format here. If you dont provide one, installation will proceed and either you already had one from backups or yopu can always add this later

# same for system files
SOURCE="system"
# Note : you only need the file that match your AMI, package-system7-for-splunk.tar.gz gfor RH like and AWS2
#for j in package-systemaws1-for-splunk.tar.gz package-system7-for-splunk.tar.gz package-systemdebian-for-splunk.tar.gz 
for j in package-system7-for-splunk.tar.gz 
do
  if [ -e ./$SOURCE/$j ]; then 
    \cp -p ./$SOURCE/$j  "$i/bucket-install/install/"
   else
    echo "ERROR : missing file ./$SOURCE/$j, please read comment in script and evaluate if you need it then relaunch if necessary"
  fi
done
# same for system files
# creating structure for backup bucket
mkdir -p $i/bucket-backup/splunkconf-backup

