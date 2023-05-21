#!/bin/bash

# Matthieu Araman , Splunk
# this script called by terraform
# 20210111 change paths to ref new buckets dirstructure
# 20210113 path change
# 20230314 version just for ansible playbook for worker
# 20230521 split ansible into 2 files


# first arg = bucket install
# second arg = bucket backup

s3_install=$1
s3_backup=$2
#aws s3 sync ../buckets/bucket-backup/splunkconf-backup s3://${s3_backup}/splunkconf-backup/ --storage-class STANDARD_IA; 
#aws s3 sync ../buckets/bucket-install/packaged s3://${s3_install}/packaged/ --storage-class STANDARD_IA; 
#aws s3 sync ../buckets/bucket-install/install s3://${s3_install}/install/ --storage-class STANDARD_IA
aws s3 cp ./ansible_jinja_tf.yml s3://${s3_install}/install/ --storage-class STANDARD_IA
aws s3 cp ./ansible_jinja_byhost_tf.yml s3://${s3_install}/install/ --storage-class STANDARD_IA
