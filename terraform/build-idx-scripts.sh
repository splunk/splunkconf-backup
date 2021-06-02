#!/bin/bash

# This script package files that will be deployed on indexers only

if [ "$#" -ne 1 ]; then 
  echo "illegal number of parameters, you should provide the instance type"
  exit 1
fi

instancetype=$1

mkdir -p ./build-idx
find ./build-idx -type f -exec rm {} \;
mkdir -p ./build-idx/usr/local/bin/ ./build-idx/opt/splunk/scripts
if [ -e "./scripts-template/splunkconf-aws-terminate-idx.sh" ]; then
  cp -p ./scripts-template/splunkconf-aws-terminate-idx.sh ./build-idx/usr/local/bin/
  chmod 555 ./build-idx/usr/local/bin/splunkconf-aws-terminate-idx.sh
fi
mkdir -p ../buckets/bucket-backup/splunkconf-backup/${instancetype}
tar -C"./build-idx" --exclude "._*" --exclude ".DS*" -zcvf ../buckets/bucket-backup/splunkconf-backup/${instancetype}/backupconfsplunk-scripts-initial.tar.gz ./opt/splunk/scripts ./usr/local/bin
