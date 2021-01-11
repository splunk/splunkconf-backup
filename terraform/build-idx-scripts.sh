#!/bin/bash

# This script package files that will be deployed on indexers only

if [$# -ne 1]; 
    then echo "illegal number of parameters, you should provide the instance type"
fi

instancetype=$1


find ./build-idx -type f -exec rm {} \;mkdir -p ./build-idx/usr/local/bin/ /build-idx/opt/splunk/scripts; cp -p ./scripts-template/splunkconf-aws-terminate-idx.sh ./build-idx/usr/local/bin/ ; chmod 555 ./build-idx/usr/local/bin/splunkconf-aws-terminate-idx; tar -C"./build-idx" --exclude "._*" --exclude ".DS*" -zcvf ./bucket-backup/splunkconf-backup/${instancetype}/backupconfsplunk-scripts-initial.tar.gz ./opt/splunk/scripts ./usr/local/bin
