#!/bin/bash

# This script package files that will be deployed on indexers only

if [ "$#" -ne 1 ]; then 
  echo "illegal number of parameters, you should provide the instance type"
  exit 1
fi

instancetype=$1


find ./build-nonidx -type f -exec rm {} \;
mkdir -p ./build-nonidx/usr/local/bin/ ./build-nonidx/opt/splunk/scripts
cp -p ./scripts-template/aws-update-dns.sh ./build-nonidx/usr/local/bin/aws-postinstall.sh
chmod 555 ./build-idx/usr/local/bin/aws-postinstall.sh
mkdir -p ../buckets/bucket-backup/splunkconf-backup/${instancetype}
tar -C"./build-idx" --exclude "._*" --exclude ".DS*" -zcvf ../buckets/bucket-backup/splunkconf-backup/${instancetype}/backupconfsplunk-scripts-initial.tar.gz ./opt/splunk/scripts ./usr/local/bin
