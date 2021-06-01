#!/bin/bash

# Matthieu Araman , Splunk
# this script called by terraform
# 20210111 change paths to ref new buckets dirstructure
# 20210113 path change
# 20210124 version for gcs


# first arg = bucket install
# second arg = bucket backup

s3_install=$1
s3_backup=$2
gsutil rsync -r ../buckets/bucket-backup/splunkconf-backup ${s3_backup}/splunkconf-backup/ 
gsutil rsync -r ../buckets/bucket-install/packaged ${s3_install}/packaged/ 
gsutil rsync -r ../buckets/bucket-install/install ${s3_install}/install/ 
